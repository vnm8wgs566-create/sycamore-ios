-- The profile photo finally has somewhere to live.
--
-- `profiles.avatar_url` has held a URL into Storage since the schema was written, and no bucket
-- existed — so `ProfileView.loadPhoto` wrote bytes into an in-memory field and
-- `SupabaseRepository.updateAccount` carried them back without saving, under a comment saying so.
-- A photo survived until sign-out and then did not.
--
-- Applied to the live project on 2026-08-10 and written down here so a rebuilt project has it too.
--
-- Private, not public. A coach's face is not something to publish at a guessable URL, and the app
-- always holds a session when it needs one: the client fetches through an authenticated GET.

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'avatars',
  'avatars',
  false,
  2097152,                              -- 2 MiB. `loadPhoto` sends ~80 KiB; this is the runaway guard.
  array['image/jpeg', 'image/png', 'image/heic', 'image/webp']
)
on conflict (id) do update
  set file_size_limit    = excluded.file_size_limit,
      allowed_mime_types = excluded.allowed_mime_types,
      public             = excluded.public;

-- One folder per person, named by their auth uid, which is what every policy below keys on:
-- `avatars/<uid>/avatar.jpg`. `storage.foldername(name)` splits the object path, so `[1]` is that
-- first segment. The leaf is fixed so a new photo replaces the old one rather than accumulating.
--
-- Four policies rather than one `for all`, because the four verbs are four different questions and
-- a single policy would have to answer them with one predicate. They agree today; a future
-- "admins can see their staff's photos" changes select and nothing else.

drop policy if exists "avatar_owner_read"   on storage.objects;
drop policy if exists "avatar_owner_insert" on storage.objects;
drop policy if exists "avatar_owner_update" on storage.objects;
drop policy if exists "avatar_owner_delete" on storage.objects;

create policy "avatar_owner_read" on storage.objects
  for select to authenticated
  using (bucket_id = 'avatars' and (storage.foldername(name))[1] = auth.uid()::text);

create policy "avatar_owner_insert" on storage.objects
  for insert to authenticated
  with check (bucket_id = 'avatars' and (storage.foldername(name))[1] = auth.uid()::text);

-- `using` gates which rows may be reached, `with check` gates what they may become. Both, or a
-- caller could reach their own object and rewrite its path into somebody else's folder.
create policy "avatar_owner_update" on storage.objects
  for update to authenticated
  using (bucket_id = 'avatars' and (storage.foldername(name))[1] = auth.uid()::text)
  with check (bucket_id = 'avatars' and (storage.foldername(name))[1] = auth.uid()::text);

create policy "avatar_owner_delete" on storage.objects
  for delete to authenticated
  using (bucket_id = 'avatars' and (storage.foldername(name))[1] = auth.uid()::text);
