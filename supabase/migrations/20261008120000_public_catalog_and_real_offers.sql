-- Real shops and offers, a public catalogue for visitors who are not signed
-- in, and a closing state for bags that were never picked up.
begin;

-- 1. Shops and the offers merchants publish are real. Only the sample set from
-- wasteless_merchant('seed') stays marked as demo.
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
   -- New shops start as 'pending' (column default) until approved. Shops and
   -- the offers they publish are real; only the optional sample set is demo.
   insert into public.merchants(owner_id,name,address,pickup_window,latitude,longitude,is_demo) values(u,trim(p_data->>'name'),trim(p_data->>'address'),trim(p_data->>'pickup_window'),(p_data->>'latitude')::float8,(p_data->>'longitude')::float8,false) returning id into m;
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
  values(m,n,p_data->>'description',v_price,original,v_stock,p_data->>'category',p_data->>'allergens',p_data->>'image_path',false,ps,pe) returning id into pid;
 else
  update public.product set name=n,description=p_data->>'description',price=v_price,original_price=original,stock=v_stock,category=p_data->>'category',allergens=p_data->>'allergens',image_path=p_data->>'image_path',pickup_start=ps,pickup_end=pe,updated_at=now() where id=pid and merchant_id=m;
  if not found then raise sqlstate 'PT404' using message='Product not found'; end if;
 end if;
 return pid;
end $$;

-- 2. Public catalogue: visitors browse approved shops and live offers without
-- an account. Same visibility rules as catalog_read / merchant_directory, and
-- only the columns the app shows (no owner ids).
create function public.wasteless_catalog(p_id bigint default null,p_offset integer default 0,p_limit integer default 50)
returns jsonb language sql stable security definer set search_path='' as $$
 select coalesce(jsonb_agg(x.item order by x.id),'[]'::jsonb) from (
  select p.id,jsonb_build_object(
   'id',p.id,'name',p.name,'description',p.description,'image_path',p.image_path,
   'price',p.price,'stock',p.stock,'category',p.category,'location_id',p.location_id,
   'active',p.active,'merchant_id',p.merchant_id,'original_price',p.original_price,
   'allergens',p.allergens,'is_demo',p.is_demo,'pickup_start',p.pickup_start,'pickup_end',p.pickup_end,
   'merchants',case when m.id is null then null else jsonb_build_object(
    'id',m.id,'name',m.name,'address',m.address,'pickup_window',m.pickup_window,
    'latitude',m.latitude,'longitude',m.longitude,'image_url',m.image_url) end) as item
  from public.product p left join public.merchants m on m.id=p.merchant_id
  where (p_id is null or p.id=p_id) and p.active and p.name is not null
   and p.price>=0 and p.stock>=0 and (p.pickup_end is null or p.pickup_end>now())
   and (p.merchant_id is null or m.status='approved')
  order by p.id
  offset greatest(coalesce(p_offset,0),0) limit least(greatest(coalesce(p_limit,50),1),101)
 ) x;
$$;
create function public.wasteless_shops() returns jsonb
language sql stable security definer set search_path='' as $$
 select coalesce(jsonb_agg(jsonb_build_object(
  'id',m.id,'name',m.name,'address',m.address,'pickup_window',m.pickup_window,
  'latitude',m.latitude,'longitude',m.longitude,'is_demo',m.is_demo,'image_url',m.image_url) order by m.id),'[]'::jsonb)
 from (select * from public.merchants
  where owner_id is not null and name is not null and status='approved' order by id limit 100) m;
$$;
revoke all on function public.wasteless_catalog(bigint,integer,integer),public.wasteless_shops() from public;
grant execute on function public.wasteless_catalog(bigint,integer,integer),public.wasteless_shops() to anon,authenticated;

-- 3. Bags nobody picked up: once the pickup window has ended the merchant
-- closes the order as not collected. The food is gone, so stock stays as is.
alter table public."order" drop constraint order_status_check;
alter table public."order" add constraint order_status_check
  check(status in ('confirmed','accepted','ready','collected','cancelled','not_collected'));

create or replace function private.wasteless_order_transition(p_order_id bigint,p_status text,p_code text default '',p_reason text default '') returns void
language plpgsql security definer set search_path='' as $$
declare u uuid:=auth.uid(); o public."order"%rowtype; owns boolean; r record;
begin
 if u is null then raise sqlstate 'PT401' using message='Authentication required'; end if;
 select * into o from public."order" where id=p_order_id for update;
 if not found then raise sqlstate 'PT404' using message='Order not found'; end if;
 owns:=exists(select 1 from public.merchants where id=o.merchant_id and owner_id=u);
 if o.user_id<>u and not owns then raise sqlstate 'PT404' using message='Order not found'; end if;
 if p_status not in ('accepted','ready','collected','cancelled','not_collected') or p_status is null then raise sqlstate 'PT422' using message='Invalid status'; end if;
 if p_status<>'cancelled' and not owns then raise sqlstate 'PT403' using message='Merchant required'; end if;
 if o.status=p_status then return; end if;
 if p_status='cancelled' then
  if o.status not in ('confirmed','accepted','ready') then raise sqlstate 'PT409' using message='Order cannot be cancelled'; end if;
  if length(trim(coalesce(p_reason,''))) not between 3 and 500 then raise sqlstate 'PT422' using message='Cancellation reason required'; end if;
  for r in select product_id,quantity from public.order_items where order_id=o.id order by product_id loop
   update public.product set stock=stock+r.quantity where id=r.product_id;
  end loop;
 elsif p_status='not_collected' then
  if o.status not in ('confirmed','accepted','ready') then raise sqlstate 'PT409' using message='Invalid transition'; end if;
  if o.pickup_end is not null and o.pickup_end>now() then raise sqlstate 'PT409' using message='Pickup not ended'; end if;
 elsif not ((o.status='confirmed' and p_status='accepted') or (o.status='accepted' and p_status='ready') or (o.status='ready' and p_status='collected')) then raise sqlstate 'PT409' using message='Invalid transition';
 end if;
 if p_status='collected' and upper(trim(p_code)) is distinct from o.pickup_code then raise sqlstate 'PT422' using message='Invalid pickup code'; end if;
 update public."order" set status=p_status,updated_at=now(),cancellation_reason=case when p_status='cancelled' then trim(p_reason) else null end where id=o.id;
end $$;

notify pgrst,'reload schema';
commit;
