begin;
alter table public.merchants add column owner_id uuid references auth.users(id), add column name text, add column address text, add column pickup_window text, add column latitude double precision, add column longitude double precision, add column is_demo boolean not null default true, add column demo_seeded boolean not null default false;
create unique index merchant_owner_unique on public.merchants(owner_id) where owner_id is not null;
alter table public.merchants add constraint merchant_coordinates check(latitude between -90 and 90 and longitude between -180 and 180);
alter table public.product add column merchant_id bigint references public.merchants(id), add column original_price numeric(12,2), add column allergens text, add column is_demo boolean not null default false;
create index product_merchant on public.product(merchant_id);
alter table public."order" drop constraint order_status_check;
alter table public."order" add constraint order_status_check check(status in ('confirmed','accepted','ready','collected','cancelled'));
alter table public."order" add column merchant_id bigint references public.merchants(id), add column merchant_name text, add column pickup_address text, add column pickup_window text, add column pickup_code text, add column is_demo boolean not null default false, add column cancellation_reason text;
create index orders_merchant_created on public."order"(merchant_id,created_at desc);
alter table public.merchants enable row level security;
revoke all on public.merchants from anon,authenticated;
grant select on public.merchants to authenticated;
create policy merchant_directory on public.merchants for select to authenticated using(owner_id is not null and name is not null);
create policy merchant_products on public.product for select to authenticated using(exists(select 1 from public.merchants m where m.id=merchant_id and m.owner_id=(select auth.uid())));
create policy merchant_orders on public."order" for select to authenticated using(exists(select 1 from public.merchants m where m.id=merchant_id and m.owner_id=(select auth.uid())));
create policy merchant_order_items on public.order_items for select to authenticated using(exists(select 1 from public."order" o join public.merchants m on m.id=o.merchant_id where o.id=order_id and m.owner_id=(select auth.uid())));

create function private.wasteless_merchant(p_action text,p_data jsonb) returns bigint
language plpgsql security definer set search_path='' as $$
declare u uuid:=auth.uid(); m bigint; pid bigint; n text; v_price numeric; original numeric; v_stock integer;
begin
 if u is null then raise sqlstate 'PT401' using message='Authentication required'; end if;
 perform pg_advisory_xact_lock(hashtextextended(u::text,0));
 select id into m from public.merchants where owner_id=u for update;
 if p_action='profile' then
  if length(trim(coalesce(p_data->>'name',''))) not between 2 and 100 or length(trim(coalesce(p_data->>'address',''))) not between 5 and 300 or length(trim(coalesce(p_data->>'pickup_window',''))) not between 3 and 100 or (p_data->>'latitude') is null or (p_data->>'longitude') is null then raise sqlstate 'PT422' using message='Invalid merchant profile'; end if;
  if m is null then
   insert into public.merchants(owner_id,name,address,pickup_window,latitude,longitude,is_demo) values(u,trim(p_data->>'name'),trim(p_data->>'address'),trim(p_data->>'pickup_window'),(p_data->>'latitude')::float8,(p_data->>'longitude')::float8,true) returning id into m;
  else
   update public.merchants set name=trim(p_data->>'name'),address=trim(p_data->>'address'),pickup_window=trim(p_data->>'pickup_window'),latitude=(p_data->>'latitude')::float8,longitude=(p_data->>'longitude')::float8,updated_at=now() where id=m;
  end if;
  return m;
 end if;
 if m is null then raise sqlstate 'PT403' using message='Merchant profile required'; end if;
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
 if n is null or length(n) not between 2 and 150 or v_price is null or v_price<=0 or v_price>10000 or original is null or original<v_price or original>10000 or v_stock is null or v_stock not between 0 and 10000 or length(trim(coalesce(p_data->>'allergens',''))) not between 2 and 500 then raise sqlstate 'PT422' using message='Invalid product'; end if;
 if coalesce(p_data->>'image_path','') not in ('assets/demo/apples.webp','assets/demo/pears.webp','assets/demo/rescue-bag.webp') then raise sqlstate 'PT422' using message='Invalid image'; end if;
 if pid is null then
  insert into public.product(merchant_id,name,description,price,original_price,stock,category,allergens,image_path,is_demo)
  values(m,n,p_data->>'description',v_price,original,v_stock,p_data->>'category',p_data->>'allergens',p_data->>'image_path',true) returning id into pid;
 else
  update public.product set name=n,description=p_data->>'description',price=v_price,original_price=original,stock=v_stock,category=p_data->>'category',allergens=p_data->>'allergens',image_path=p_data->>'image_path',updated_at=now() where id=pid and merchant_id=m;
  if not found then raise sqlstate 'PT404' using message='Product not found'; end if;
 end if;
 return pid;
end $$;

create or replace function private.wasteless_checkout(p_key uuid) returns bigint
language plpgsql security definer set search_path='' as $$
declare u uuid:=auth.uid(); c bigint; oid bigint; r record; amount numeric(12,2):=0; mid bigint; shop public.merchants%rowtype; demo boolean;
begin
 if u is null then raise sqlstate 'PT401' using message='Authentication required'; end if;
 if p_key is null then raise sqlstate 'PT422' using message='Idempotency key required'; end if;
 perform pg_advisory_xact_lock(hashtextextended(u::text,0));
 select id into oid from public."order" where user_id=u and idempotency_key=p_key;
 if found then return oid; end if;
 select id into c from public.cart where user_id=u for update;
 if c is null or not exists(select 1 from public.cart_items where cart_id=c) then raise sqlstate 'PT409' using message='Empty cart'; end if;
 for r in select p.id,p.price,p.stock,p.active,i.quantity from public.cart_items i join public.product p on p.id=i.product_id where i.cart_id=c order by p.id for update of p loop
  if not r.active or r.price is null or r.stock is null or r.quantity>r.stock then raise sqlstate 'PT409' using message='Product unavailable'; end if;
  amount:=amount+r.price*r.quantity;
 end loop;
 if (select count(distinct coalesce(p.merchant_id,-1)) from public.cart_items i join public.product p on p.id=i.product_id where i.cart_id=c)>1 then raise sqlstate 'PT409' using message='One merchant per order'; end if;
 select p.merchant_id,bool_and(p.is_demo) over() into mid,demo from public.cart_items i join public.product p on p.id=i.product_id where i.cart_id=c limit 1;
 if mid is not null then select * into shop from public.merchants where id=mid; end if;
 insert into public."order"(user_id,subtotal,total_price,status,idempotency_key,merchant_id,merchant_name,pickup_address,pickup_window,pickup_code,is_demo)
 values(u,amount,amount,'confirmed',p_key,mid,shop.name,shop.address,shop.pickup_window,upper(substr(replace(gen_random_uuid()::text,'-',''),1,8)),coalesce(demo,false)) returning id into oid;
 insert into public.order_items(order_id,product_id,quantity,product_name,unit_price)
 select oid,p.id,i.quantity,p.name,p.price from public.cart_items i join public.product p on p.id=i.product_id where i.cart_id=c;
 update public.product p set stock=p.stock-i.quantity from public.cart_items i where i.cart_id=c and p.id=i.product_id;
 delete from public.cart_items where cart_id=c;
 return oid;
end $$;

create function private.wasteless_order_transition(p_order_id bigint,p_status text,p_code text default '',p_reason text default '') returns void
language plpgsql security definer set search_path='' as $$
declare u uuid:=auth.uid(); o public."order"%rowtype; owns boolean; r record;
begin
 if u is null then raise sqlstate 'PT401' using message='Authentication required'; end if;
 select * into o from public."order" where id=p_order_id for update;
 if not found then raise sqlstate 'PT404' using message='Order not found'; end if;
 owns:=exists(select 1 from public.merchants where id=o.merchant_id and owner_id=u);
 if o.user_id<>u and not owns then raise sqlstate 'PT404' using message='Order not found'; end if;
 if p_status not in ('accepted','ready','collected','cancelled') or p_status is null then raise sqlstate 'PT422' using message='Invalid status'; end if;
 if p_status<>'cancelled' and not owns then raise sqlstate 'PT403' using message='Merchant required'; end if;
 if o.status=p_status then return; end if;
 if p_status='cancelled' then
  if o.status not in ('confirmed','accepted','ready') then raise sqlstate 'PT409' using message='Order cannot be cancelled'; end if;
  if length(trim(coalesce(p_reason,''))) not between 3 and 500 then raise sqlstate 'PT422' using message='Cancellation reason required'; end if;
  for r in select product_id,quantity from public.order_items where order_id=o.id order by product_id loop
   update public.product set stock=stock+r.quantity where id=r.product_id;
  end loop;
 elsif not ((o.status='confirmed' and p_status='accepted') or (o.status='accepted' and p_status='ready') or (o.status='ready' and p_status='collected')) then raise sqlstate 'PT409' using message='Invalid transition';
 end if;
 if p_status='collected' and upper(trim(p_code)) is distinct from o.pickup_code then raise sqlstate 'PT422' using message='Invalid pickup code'; end if;
 update public."order" set status=p_status,updated_at=now(),cancellation_reason=case when p_status='cancelled' then trim(p_reason) else null end where id=o.id;
end $$;
create function public.wasteless_merchant(p_action text,p_data jsonb) returns bigint language sql security invoker set search_path='' as $$select private.wasteless_merchant(p_action,p_data)$$;
create function public.wasteless_order_transition(p_order_id bigint,p_status text,p_code text default '',p_reason text default '') returns void language sql security invoker set search_path='' as $$select private.wasteless_order_transition(p_order_id,p_status,p_code,p_reason)$$;
revoke all on function private.wasteless_merchant(text,jsonb),public.wasteless_merchant(text,jsonb),private.wasteless_order_transition(bigint,text,text,text),public.wasteless_order_transition(bigint,text,text,text) from public,anon;
grant execute on function private.wasteless_merchant(text,jsonb),public.wasteless_merchant(text,jsonb),private.wasteless_order_transition(bigint,text,text,text),public.wasteless_order_transition(bigint,text,text,text) to authenticated;
notify pgrst,'reload schema';
commit;
