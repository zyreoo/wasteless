-- A live marketplace: shops are listed as soon as their profile is complete,
-- sample data is gone, and shops can be listed before an account is attached.
begin;

-- Shops go live immediately. A shop can still be hidden by setting its status
-- to 'pending' or 'rejected'; until now approval had no screen and new shops
-- silently stayed invisible to customers.
alter table public.merchants alter column status set default 'approved';
alter table public.merchants alter column is_demo set default false;
update public.merchants set status='approved' where status='pending';

-- Approved shops are listed even before a merchant account is attached.
drop policy merchant_directory on public.merchants;
create policy merchant_directory on public.merchants for select to authenticated using(
  (name is not null and status = 'approved') or owner_id = (select auth.uid()));
create or replace function public.wasteless_shops() returns jsonb
language sql stable security definer set search_path='' as $$
 select coalesce(jsonb_agg(jsonb_build_object(
  'id',m.id,'name',m.name,'address',m.address,'pickup_window',m.pickup_window,
  'latitude',m.latitude,'longitude',m.longitude,'is_demo',m.is_demo,'image_url',m.image_url) order by m.id),'[]'::jsonb)
 from (select * from public.merchants
  where name is not null and status='approved' order by id limit 100) m;
$$;

-- No more sample products: 'seed' is no longer an action.
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
   -- New shops are live as soon as the profile is complete (column default).
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

notify pgrst,'reload schema';
commit;
