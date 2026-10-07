-- Shop photos bucket: public read; each merchant writes only in a folder named
-- after their own user id. Uploads go through the API with the user's token.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('shop-images', 'shop-images', true, 2097152, array['image/jpeg','image/png','image/webp'])
on conflict (id) do update set public = excluded.public,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

create policy shop_images_owner_insert on storage.objects for insert to authenticated
  with check (bucket_id = 'shop-images' and (storage.foldername(name))[1] = (select auth.uid())::text);
create policy shop_images_owner_select on storage.objects for select to authenticated
  using (bucket_id = 'shop-images' and (storage.foldername(name))[1] = (select auth.uid())::text);
create policy shop_images_owner_delete on storage.objects for delete to authenticated
  using (bucket_id = 'shop-images' and (storage.foldername(name))[1] = (select auth.uid())::text);
