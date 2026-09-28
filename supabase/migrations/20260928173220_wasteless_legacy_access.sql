begin;
-- The application uses public.cart. Preserve the unrelated legacy rows but
-- remove anonymous and ordinary user access to the unowned legacy table.
do $$ begin
 if to_regclass('tebelenoi.cart') is not null then
  alter table tebelenoi.cart enable row level security;
  revoke all on tebelenoi.cart from anon,authenticated;
 end if;
 if to_regprocedure('public.rls_auto_enable()') is not null then
  revoke execute on function public.rls_auto_enable() from public,anon,authenticated;
 end if;
end $$;
commit;
