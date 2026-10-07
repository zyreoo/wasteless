-- Marketplace foundations: shop photos, dated pickup windows on surprise bags,
-- and merchant approval before a shop becomes visible to customers.
begin;

-- 1. Shops: photo and approval status. Shops that already exist stay visible.
alter table public.merchants
  add column image_url text,
  add column status text not null default 'approved';
alter table public.merchants alter column status set default 'pending';
alter table public.merchants add constraint merchant_status_check
  check (status in ('pending','approved','rejected'));
-- Only photos stored in the shop-images bucket; the owner folder is checked
-- again by wasteless_merchant('photo').
alter table public.merchants add constraint merchant_image_url_check
  check (image_url is null or image_url ~ '^https://[^/]+/storage/v1/object/public/shop-images/[0-9a-f-]{36}/[A-Za-z0-9._-]{1,120}$');

-- 2. Dated pickup windows on bags, snapshotted onto orders.
alter table public.product
  add column pickup_start timestamptz,
  add column pickup_end timestamptz;
alter table public.product add constraint product_pickup_window_check
  check ((pickup_start is null) = (pickup_end is null) and (pickup_end is null or pickup_end > pickup_start));
create index product_pickup_end on public.product(pickup_end);
alter table public."order"
  add column pickup_start timestamptz,
  add column pickup_end timestamptz;

-- 3. Customers see only bags of approved shops whose pickup has not ended.
drop policy catalog_read on public.product;
create policy catalog_read on public.product for select to authenticated using(
  active and name is not null and price >= 0 and stock >= 0
  and (pickup_end is null or pickup_end > now())
  and (merchant_id is null or exists(
    select 1 from public.merchants m where m.id = merchant_id and m.status = 'approved')));
drop policy merchant_directory on public.merchants;
create policy merchant_directory on public.merchants for select to authenticated using(
  (owner_id is not null and name is not null and status = 'approved')
  or owner_id = (select auth.uid()));

-- Security-definer functions bypass RLS, so they share this explicit check.
create function private.wasteless_orderable(p_product_id bigint) returns boolean
language sql stable security definer set search_path='' as $$
  select exists(
    select 1 from public.product p
    left join public.merchants m on m.id = p.merchant_id
    where p.id = p_product_id and p.active and p.name is not null
      and p.price >= 0 and p.stock >= 0
      and (p.pickup_end is null or p.pickup_end > now())
      and (p.merchant_id is null or m.status = 'approved'));
$$;
revoke all on function private.wasteless_orderable(bigint) from public, anon, authenticated;

create or replace function private.wasteless_cart(p_action text,p_product_id bigint default null,p_item_id bigint default null,p_quantity integer default null)
returns void language plpgsql security definer set search_path='' as $$
declare u uuid:=auth.uid(); c bigint; available bigint; current_qty bigint;
begin
 if u is null then raise sqlstate 'PT401' using message='Authentication required'; end if;
 perform pg_advisory_xact_lock(hashtextextended(u::text,0));
 if p_action not in ('add','set','remove','clear') then raise sqlstate 'PT422' using message='Invalid operation'; end if;
 insert into public.cart(user_id) values(u) on conflict(user_id) do nothing;
 select id into c from public.cart where user_id=u for update;
 if p_action='clear' then delete from public.cart_items where cart_id=c; return; end if;
 if p_action in ('set','remove') then
  select product_id into p_product_id from public.cart_items where id=p_item_id and cart_id=c;
  if not found then raise sqlstate 'PT404' using message='Cart item not found'; end if;
 end if;
 if p_action='remove' or (p_action='set' and p_quantity=0) then
  delete from public.cart_items where id=p_item_id and cart_id=c; return;
 end if;
 if p_quantity is null or p_quantity not between 1 and 99 then raise sqlstate 'PT422' using message='Invalid quantity'; end if;
 if not private.wasteless_orderable(p_product_id) then raise sqlstate 'PT404' using message='Product not found'; end if;
 select stock into available from public.product where id=p_product_id;
 select quantity into current_qty from public.cart_items where cart_id=c and product_id=p_product_id;
 if p_action='add' then p_quantity:=p_quantity+coalesce(current_qty,0); end if;
 if p_quantity>99 or p_quantity>available then raise sqlstate 'PT409' using message='Insufficient stock'; end if;
 insert into public.cart_items(cart_id,product_id,quantity) values(c,p_product_id,p_quantity)
 on conflict(cart_id,product_id) do update set quantity=excluded.quantity;
 update public.cart set updated_at=now() where id=c;
end $$;

create or replace function private.wasteless_favorite(p_product_id bigint,p_saved boolean)
returns void language plpgsql security definer set search_path='' as $$
declare u uuid:=auth.uid(); begin
 if u is null then raise sqlstate 'PT401' using message='Authentication required'; end if;
 if p_saved then
  if not private.wasteless_orderable(p_product_id) then raise sqlstate 'PT404' using message='Product not found'; end if;
  insert into public.favorite(user_id,items_id) values(u,p_product_id) on conflict(user_id,items_id) do nothing;
 else delete from public.favorite where user_id=u and items_id=p_product_id;
 end if;
end $$;

create or replace function private.wasteless_checkout(p_key uuid) returns bigint
language plpgsql security definer set search_path='' as $$
declare u uuid:=auth.uid(); c bigint; oid bigint; r record; amount numeric(12,2):=0; mid bigint; shop public.merchants%rowtype; demo boolean; ps timestamptz; pe timestamptz;
begin
 if u is null then raise sqlstate 'PT401' using message='Authentication required'; end if;
 if p_key is null then raise sqlstate 'PT422' using message='Idempotency key required'; end if;
 perform pg_advisory_xact_lock(hashtextextended(u::text,0));
 select id into oid from public."order" where user_id=u and idempotency_key=p_key;
 if found then return oid; end if;
 select id into c from public.cart where user_id=u for update;
 if c is null or not exists(select 1 from public.cart_items where cart_id=c) then raise sqlstate 'PT409' using message='Empty cart'; end if;
 for r in select p.id,p.price,p.stock,p.active,i.quantity from public.cart_items i join public.product p on p.id=i.product_id where i.cart_id=c order by p.id for update of p loop
  if not r.active or r.price is null or r.stock is null or r.quantity>r.stock or not private.wasteless_orderable(r.id) then raise sqlstate 'PT409' using message='Product unavailable'; end if;
  amount:=amount+r.price*r.quantity;
 end loop;
 if (select count(distinct coalesce(p.merchant_id,-1)) from public.cart_items i join public.product p on p.id=i.product_id where i.cart_id=c)>1 then raise sqlstate 'PT409' using message='One merchant per order'; end if;
 if (select count(distinct coalesce(p.pickup_start::text,'')||'/'||coalesce(p.pickup_end::text,'')) from public.cart_items i join public.product p on p.id=i.product_id where i.cart_id=c)>1 then raise sqlstate 'PT409' using message='One pickup window per order'; end if;
 select p.merchant_id,p.pickup_start,p.pickup_end,bool_and(p.is_demo) over() into mid,ps,pe,demo from public.cart_items i join public.product p on p.id=i.product_id where i.cart_id=c limit 1;
 if mid is not null then select * into shop from public.merchants where id=mid; end if;
 insert into public."order"(user_id,subtotal,total_price,status,idempotency_key,merchant_id,merchant_name,pickup_address,pickup_window,pickup_code,is_demo,pickup_start,pickup_end)
 values(u,amount,amount,'confirmed',p_key,mid,shop.name,shop.address,shop.pickup_window,upper(substr(replace(gen_random_uuid()::text,'-',''),1,8)),coalesce(demo,false),ps,pe) returning id into oid;
 insert into public.order_items(order_id,product_id,quantity,product_name,unit_price)
 select oid,p.id,i.quantity,p.name,p.price from public.cart_items i join public.product p on p.id=i.product_id where i.cart_id=c;
 update public.product p set stock=p.stock-i.quantity from public.cart_items i where i.cart_id=c and p.id=i.product_id;
 delete from public.cart_items where cart_id=c;
 return oid;
end $$;

create or replace function private.wasteless_merchant(p_action text,p_data jsonb) returns bigint
language plpgsql security definer set search_path='' as $$
declare u uuid:=auth.uid(); m bigint; pid bigint; n text; v_price numeric; original numeric; v_stock integer; ps timestamptz; pe timestamptz; url text;
begin
 if u is null then raise sqlstate 'PT401' using message='Authentication required'; end if;
 perform pg_advisory_xact_lock(hashtextextended(u::text,0));
 select id into m from public.merchants where owner_id=u for update;
 if p_action='profile' then
  if length(trim(coalesce(p_data->>'name',''))) not between 2 and 100 or length(trim(coalesce(p_data->>'address',''))) not between 5 and 300 or length(trim(coalesce(p_data->>'pickup_window',''))) not between 3 and 100 or (p_data->>'latitude') is null or (p_data->>'longitude') is null then raise sqlstate 'PT422' using message='Invalid merchant profile'; end if;
  if m is null then
   -- New shops start as 'pending' (column default) until approved.
   insert into public.merchants(owner_id,name,address,pickup_window,latitude,longitude,is_demo) values(u,trim(p_data->>'name'),trim(p_data->>'address'),trim(p_data->>'pickup_window'),(p_data->>'latitude')::float8,(p_data->>'longitude')::float8,true) returning id into m;
  else
   update public.merchants set name=trim(p_data->>'name'),address=trim(p_data->>'address'),pickup_window=trim(p_data->>'pickup_window'),latitude=(p_data->>'latitude')::float8,longitude=(p_data->>'longitude')::float8,updated_at=now() where id=m;
  end if;
  return m;
 end if;
 if m is null then raise sqlstate 'PT403' using message='Merchant profile required'; end if;
 if p_action='photo' then
  url:=nullif(trim(coalesce(p_data->>'image_url','')),'');
  if url is not null and position('/storage/v1/object/public/shop-images/'||u::text||'/' in url)=0 then raise sqlstate 'PT422' using message='Invalid image'; end if;
  update public.merchants set image_url=url,updated_at=now() where id=m;
  return m;
 end if;
 if p_action='seed' then
  if (select demo_seeded from public.merchants where id=m) then return m; end if;
  insert into public.product(merchant_id,name,description,price,original_price,stock,category,allergens,image_path,is_demo) values
  (m,'Pachet de brutărie · DEMO','Produse fictive pentru testarea rezervării și ridicării.',19,55,8,'Brutărie','Gluten, lapte, ouă','assets/demo/rescue-bag.webp',true),
  (m,'Mere de sezon · DEMO','Pachet fictiv de 1 kg, pentru simulare.',8,15,12,'Fructe','Fără alergeni declarați în simulare','assets/demo/apples.webp',true),
  (m,'Pere de sezon · DEMO','Pachet fictiv de 1 kg, pentru simulare.',9,18,10,'Fructe','Fără alergeni declarați în simulare','assets/demo/pears.webp',true),
  (m,'Pachet vegetarian · DEMO','Exemplu epuizat. Modifică stocul pentru a-l activa.',22,60,0,'Mâncare gătită','Lapte, susan','assets/demo/rescue-bag.webp',true);
  update public.merchants set demo_seeded=true where id=m;
  return m;
 end if;
 pid:=(p_data->>'id')::bigint;
 if p_action='availability' then
  update public.product set active=(p_data->>'active')::boolean,updated_at=now() where id=pid and merchant_id=m;
  if not found then raise sqlstate 'PT404' using message='Product not found'; end if;
  return pid;
 end if;
 if p_action<>'product' then raise sqlstate 'PT422' using message='Invalid action'; end if;
 n:=trim(p_data->>'name'); v_price:=(p_data->>'price')::numeric; original:=(p_data->>'original_price')::numeric; v_stock:=(p_data->>'stock')::integer;
 ps:=(p_data->>'pickup_start')::timestamptz; pe:=(p_data->>'pickup_end')::timestamptz;
 if n is null or length(n) not between 2 and 150 or v_price is null or v_price<=0 or v_price>10000 or original is null or original<v_price or original>10000 or v_stock is null or v_stock not between 0 and 10000 or length(trim(coalesce(p_data->>'allergens',''))) not between 2 and 500 then raise sqlstate 'PT422' using message='Invalid product'; end if;
 if coalesce(p_data->>'image_path','') not in ('assets/demo/apples.webp','assets/demo/pears.webp','assets/demo/rescue-bag.webp') then raise sqlstate 'PT422' using message='Invalid image'; end if;
 -- A dated window: both ends, in the future, within a week, at most 12 hours long.
 if (ps is null) <> (pe is null) or (pe is not null and (pe<=ps or pe<=now() or ps>now()+interval '8 days' or pe-ps>interval '12 hours')) then raise sqlstate 'PT422' using message='Invalid pickup window'; end if;
 if pid is null then
  insert into public.product(merchant_id,name,description,price,original_price,stock,category,allergens,image_path,is_demo,pickup_start,pickup_end)
  values(m,n,p_data->>'description',v_price,original,v_stock,p_data->>'category',p_data->>'allergens',p_data->>'image_path',true,ps,pe) returning id into pid;
 else
  update public.product set name=n,description=p_data->>'description',price=v_price,original_price=original,stock=v_stock,category=p_data->>'category',allergens=p_data->>'allergens',image_path=p_data->>'image_path',pickup_start=ps,pickup_end=pe,updated_at=now() where id=pid and merchant_id=m;
  if not found then raise sqlstate 'PT404' using message='Product not found'; end if;
 end if;
 return pid;
end $$;

commit;
