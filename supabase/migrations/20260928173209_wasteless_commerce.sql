begin;
-- Adapt the inspected legacy schema; intentionally fail on incompatible legacy rows.
alter table public.cart_items drop constraint cart_items_cart_id_fkey;
alter table public.cart_items add constraint cart_items_product_id_fkey foreign key (product_id) references public.product(id);
alter table public.cart alter column user_id set not null;
alter table public.cart add constraint cart_owner_unique unique(user_id);
alter table public.cart_items alter column product_id set not null;
alter table public.cart_items alter column cart_id set not null;
alter table public.cart_items add constraint cart_product_unique unique(cart_id,product_id);
alter table public.cart_items add constraint cart_quantity_valid check(quantity between 1 and 99);
alter table public.favorite add column user_id uuid references auth.users(id);
alter table public.favorite alter column user_id set default auth.uid();
alter table public.favorite add constraint favorite_owned_product check(user_id is not null and items_id is not null) not valid;
alter table public.favorite add constraint favorite_owner_product_unique unique(user_id,items_id);
alter table public.product alter column price type numeric(12,2) using price::numeric;
alter table public.product add constraint product_complete check(name is not null and price is not null and stock is not null) not valid;
alter table public.product add constraint product_price_valid check(price >= 0) not valid;
alter table public.product add constraint product_stock_valid check(stock >= 0) not valid;
alter table public.product add column active boolean not null default true;
alter table public.product add column category text;
alter table public."order" alter column user_id set not null;
alter table public."order" alter column total_price type numeric(12,2) using total_price::numeric;
alter table public."order" add column subtotal numeric(12,2) not null;
alter table public."order" add column status text not null default 'confirmed' check(status in ('confirmed','collected','cancelled'));
alter table public."order" add column idempotency_key uuid not null;
alter table public."order" add constraint order_request_unique unique(user_id,idempotency_key);
alter table public.order_items alter column order_id set not null;
alter table public.order_items alter column quantity set not null;
alter table public.order_items add column product_name text not null;
alter table public.order_items add column unit_price numeric(12,2) not null check(unit_price >= 0);
alter table public.order_items add constraint order_quantity_valid check(quantity between 1 and 99);
create index order_owner_created on public."order"(user_id,created_at desc,id desc);
create index order_items_order on public.order_items(order_id);
create index cart_items_product on public.cart_items(product_id);
create index favorite_product on public.favorite(items_id);

-- Reset legacy policies if another environment had permissive defaults.
do $$ declare r record; begin
 for r in select tablename,policyname from pg_policies where schemaname='public'
 and tablename in ('cart','cart_items','favorite','order','order_items','product') loop
 execute format('drop policy %I on public.%I',r.policyname,r.tablename);
 end loop;
end $$;
alter table public.cart enable row level security;
alter table public.cart_items enable row level security;
alter table public.favorite enable row level security;
alter table public."order" enable row level security;
alter table public.order_items enable row level security;
alter table public.product enable row level security;
revoke all on public.cart,public.cart_items,public.favorite,public."order",public.order_items,public.product from anon,authenticated;
grant select on public.cart,public.cart_items,public.favorite,public."order",public.order_items,public.product to authenticated;
create policy catalog_read on public.product for select to authenticated using(active and name is not null and price >= 0 and stock >= 0);
create policy cart_read on public.cart for select to authenticated using(user_id=(select auth.uid()));
create policy cart_items_read on public.cart_items for select to authenticated using(exists(select 1 from public.cart c where c.id=cart_id and c.user_id=(select auth.uid())));
create policy favorite_read on public.favorite for select to authenticated using(user_id=(select auth.uid()));
create policy orders_read on public."order" for select to authenticated using(user_id=(select auth.uid()));
create policy order_items_read on public.order_items for select to authenticated using(exists(select 1 from public."order" o where o.id=order_id and o.user_id=(select auth.uid())));

-- All writes go through ownership-checking functions. Direct table writes are
-- denied, including attempts to forge prices, order totals or transfer owners.
create schema if not exists private;
revoke all on schema private from public;
grant usage on schema private to authenticated;
create function private.wasteless_cart(p_action text,p_product_id bigint default null,p_item_id bigint default null,p_quantity integer default null)
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
 select stock into available from public.product where id=p_product_id and active and name is not null and price >= 0 and stock >= 0;
 if not found then raise sqlstate 'PT404' using message='Product not found'; end if;
 select quantity into current_qty from public.cart_items where cart_id=c and product_id=p_product_id;
 if p_action='add' then p_quantity:=p_quantity+coalesce(current_qty,0); end if;
 if p_quantity>99 or p_quantity>available then raise sqlstate 'PT409' using message='Insufficient stock'; end if;
 insert into public.cart_items(cart_id,product_id,quantity) values(c,p_product_id,p_quantity)
 on conflict(cart_id,product_id) do update set quantity=excluded.quantity;
 update public.cart set updated_at=now() where id=c;
end $$;
create function private.wasteless_favorite(p_product_id bigint,p_saved boolean)
returns void language plpgsql security definer set search_path='' as $$
declare u uuid:=auth.uid(); begin
 if u is null then raise sqlstate 'PT401' using message='Authentication required'; end if;
 if p_saved then
  if not exists(select 1 from public.product where id=p_product_id and active and name is not null and price >= 0 and stock >= 0) then raise sqlstate 'PT404' using message='Product not found'; end if;
  insert into public.favorite(user_id,items_id) values(u,p_product_id) on conflict(user_id,items_id) do nothing;
 else delete from public.favorite where user_id=u and items_id=p_product_id;
 end if;
end $$;
create function private.wasteless_checkout(p_key uuid) returns bigint
language plpgsql security definer set search_path='' as $$
declare u uuid:=auth.uid(); c bigint; oid bigint; r record; amount numeric(12,2):=0;
begin
 if u is null then raise sqlstate 'PT401' using message='Authentication required'; end if;
 if p_key is null then raise sqlstate 'PT422' using message='Idempotency key required'; end if;
 perform pg_advisory_xact_lock(hashtextextended(u::text,0));
 select id into oid from public."order" where user_id=u and idempotency_key=p_key;
 if found then return oid; end if;
 select id into c from public.cart where user_id=u for update;
 if c is null or not exists(select 1 from public.cart_items where cart_id=c) then raise sqlstate 'PT409' using message='Empty cart'; end if;
 -- Stable product lock order also avoids deadlocks between different customers.
 for r in select p.id,p.price,p.stock,p.active,i.quantity from public.cart_items i
 join public.product p on p.id=i.product_id where i.cart_id=c order by p.id for update of p loop
  if not r.active or r.price is null or r.stock is null or r.quantity>r.stock then raise sqlstate 'PT409' using message='Product unavailable'; end if;
  amount:=amount+r.price*r.quantity;
 end loop;
 insert into public."order"(user_id,subtotal,total_price,status,idempotency_key)
 values(u,amount,amount,'confirmed',p_key) returning id into oid;
 insert into public.order_items(order_id,product_id,quantity,product_name,unit_price)
 select oid,p.id,i.quantity,p.name,p.price from public.cart_items i join public.product p on p.id=i.product_id where i.cart_id=c;
 update public.product p set stock=p.stock-i.quantity from public.cart_items i where i.cart_id=c and p.id=i.product_id;
 delete from public.cart_items where cart_id=c;
 return oid;
end $$;
revoke all on function private.wasteless_cart(text,bigint,bigint,integer),private.wasteless_favorite(bigint,boolean),private.wasteless_checkout(uuid) from public,anon;
grant execute on function private.wasteless_cart(text,bigint,bigint,integer),private.wasteless_favorite(bigint,boolean),private.wasteless_checkout(uuid) to authenticated;
create function public.wasteless_cart(p_action text,p_product_id bigint default null,p_item_id bigint default null,p_quantity integer default null)
returns void language sql security invoker set search_path='' as $$ select private.wasteless_cart(p_action,p_product_id,p_item_id,p_quantity); $$;
create function public.wasteless_favorite(p_product_id bigint,p_saved boolean)
returns void language sql security invoker set search_path='' as $$ select private.wasteless_favorite(p_product_id,p_saved); $$;
create function public.wasteless_checkout(p_key uuid)
returns bigint language sql security invoker set search_path='' as $$ select private.wasteless_checkout(p_key); $$;
revoke all on function public.wasteless_cart(text,bigint,bigint,integer),public.wasteless_favorite(bigint,boolean),public.wasteless_checkout(uuid) from public,anon;
grant execute on function public.wasteless_cart(text,bigint,bigint,integer),public.wasteless_favorite(bigint,boolean),public.wasteless_checkout(uuid) to authenticated;
notify pgrst,'reload schema';
commit;
