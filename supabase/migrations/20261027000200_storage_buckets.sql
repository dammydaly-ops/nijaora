-- ---------------------------------------------------------------------------
-- Storage buckets for owner, business and listing photos.
--
-- Paths are owner-scoped:
--   profile-photos/<auth.uid()>/<file>
--   business-photos/<business_id>/<file>
--   listing-photos/<business_id>/<listing_id>/<file>
--
-- Public read keeps marketplace photos cacheable. Writes are limited to the
-- authenticated owner of the profile/business.
-- ---------------------------------------------------------------------------

insert into storage.buckets (id, name, public)
values
  ('profile-photos', 'profile-photos', true),
  ('business-photos', 'business-photos', true),
  ('listing-photos', 'listing-photos', true)
on conflict (id) do update set public = excluded.public;

drop policy if exists "Public read marketplace photos" on storage.objects;
create policy "Public read marketplace photos"
  on storage.objects for select
  to anon, authenticated
  using (bucket_id in ('profile-photos', 'business-photos', 'listing-photos'));

drop policy if exists "Owners upload profile photos" on storage.objects;
create policy "Owners upload profile photos"
  on storage.objects for insert
  to authenticated
  with check (
    bucket_id = 'profile-photos'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

drop policy if exists "Owners update profile photos" on storage.objects;
create policy "Owners update profile photos"
  on storage.objects for update
  to authenticated
  using (
    bucket_id = 'profile-photos'
    and (storage.foldername(name))[1] = auth.uid()::text
  )
  with check (
    bucket_id = 'profile-photos'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

drop policy if exists "Owners delete profile photos" on storage.objects;
create policy "Owners delete profile photos"
  on storage.objects for delete
  to authenticated
  using (
    bucket_id = 'profile-photos'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

drop policy if exists "Owners upload business photos" on storage.objects;
create policy "Owners upload business photos"
  on storage.objects for insert
  to authenticated
  with check (
    bucket_id = 'business-photos'
    and exists (
      select 1
      from public.businesses b
      where b.id::text = (storage.foldername(name))[1]
        and b.owner_id = auth.uid()
    )
  );

drop policy if exists "Owners update business photos" on storage.objects;
create policy "Owners update business photos"
  on storage.objects for update
  to authenticated
  using (
    bucket_id = 'business-photos'
    and exists (
      select 1
      from public.businesses b
      where b.id::text = (storage.foldername(name))[1]
        and b.owner_id = auth.uid()
    )
  )
  with check (
    bucket_id = 'business-photos'
    and exists (
      select 1
      from public.businesses b
      where b.id::text = (storage.foldername(name))[1]
        and b.owner_id = auth.uid()
    )
  );

drop policy if exists "Owners delete business photos" on storage.objects;
create policy "Owners delete business photos"
  on storage.objects for delete
  to authenticated
  using (
    bucket_id = 'business-photos'
    and exists (
      select 1
      from public.businesses b
      where b.id::text = (storage.foldername(name))[1]
        and b.owner_id = auth.uid()
    )
  );

drop policy if exists "Owners upload listing photos" on storage.objects;
create policy "Owners upload listing photos"
  on storage.objects for insert
  to authenticated
  with check (
    bucket_id = 'listing-photos'
    and exists (
      select 1
      from public.businesses b
      where b.id::text = (storage.foldername(name))[1]
        and b.owner_id = auth.uid()
    )
  );

drop policy if exists "Owners update listing photos" on storage.objects;
create policy "Owners update listing photos"
  on storage.objects for update
  to authenticated
  using (
    bucket_id = 'listing-photos'
    and exists (
      select 1
      from public.businesses b
      where b.id::text = (storage.foldername(name))[1]
        and b.owner_id = auth.uid()
    )
  )
  with check (
    bucket_id = 'listing-photos'
    and exists (
      select 1
      from public.businesses b
      where b.id::text = (storage.foldername(name))[1]
        and b.owner_id = auth.uid()
    )
  );

drop policy if exists "Owners delete listing photos" on storage.objects;
create policy "Owners delete listing photos"
  on storage.objects for delete
  to authenticated
  using (
    bucket_id = 'listing-photos'
    and exists (
      select 1
      from public.businesses b
      where b.id::text = (storage.foldername(name))[1]
        and b.owner_id = auth.uid()
    )
  );
