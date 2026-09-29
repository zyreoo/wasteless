begin;

-- These are the two existing demo products in the inspected project. Stock is
-- an integer unit count, decremented atomically by wasteless_checkout().
update public.product
set stock = 10
where lower(btrim(name)) in ('mar', 'para')
  and stock is null;

commit;
