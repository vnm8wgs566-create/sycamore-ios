-- Regression from `camps_memberships_profiles`, which hardened this function with
-- `set search_path = ''` without checking its body. The body says `insert into ratings`,
-- unqualified — with an empty search_path there is no schema to resolve that against, so the
-- trigger raised 42P01 and EVERY insert into `players` failed. The app could not add a kid.
--
-- The hardening is right and stays. Qualifying the table is what should have come with it: an
-- empty search_path is only safe once every reference inside the function is schema-qualified,
-- and half of that change is worse than none of it.
--
-- `touch_updated_at()` carries the same declaration and is fine — its body only assigns
-- `new.updated_at = now()`, and `now()` resolves from `pg_catalog`, which is always implicitly
-- on the search path.

create or replace function public.seed_rating()
returns trigger
language plpgsql
set search_path to ''
as $function$
begin
  insert into public.ratings (player_id) values (new.id)
  on conflict do nothing;
  return new;
end $function$;
