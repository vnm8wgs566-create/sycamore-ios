-- Real row level security, replacing the `mvp_all` placeholders.
--
-- Eleven tables carried a single policy, `for all to public using (true)`. That is row level
-- security switched on and then opened all the way back up: with the publishable key in a
-- shipped binary, anybody could read and rewrite every row of every camp. This replaces it with
-- the rule the schema was always shaped for.
--
-- THE RULE: a person may read and write the rows of a camp they hold a membership in. Reaching a
-- row's camp means walking the graph — camps ← sites ← groups ← players ← attendance, and so on
-- — so the walk lives in `private`, in `security definer` helpers that are called once per
-- statement, rather than being re-joined for every row of every policy.
--
-- ADMIN-ONLY: three things, matching what `SetupView` already locks behind `store.isAdmin` —
--   * camp settings   (`camps` update/delete: name, sport, invite code, icon, tint)
--   * venues          (`sites` insert/update/delete, and creating/removing the courts on them)
--   * staff authority (`memberships` update — the role that *is* the permission)
-- Everything else a camp does during a session — attendance, ratings, the ladder, the inbox,
-- moving players between courts — any member may do.
--
-- ANONYMOUS CALLERS GET NOTHING. Every policy below is `to authenticated`; `anon` matches no
-- policy and so sees no rows and may write none. There is no transitional `using (true)` left
-- anywhere in this file. `auth.users` is empty today, so the seeded camp is invisible until
-- somebody signs in and joins it — see the note at the foot of this file.

-- ---------------------------------------------------------------------------
-- 1. A schema PostgREST cannot see
-- ---------------------------------------------------------------------------
-- PostgREST only exposes `public`, so nothing in here is reachable over the API even before the
-- revokes below. Belt and braces, because these functions read across every tenant.

create schema if not exists private;

revoke all on schema private from public;
revoke all on schema private from anon, authenticated;

-- `authenticated` gets `usage` back at the foot of section 2, and only there, with the reason.
-- `anon` never does: no policy below is written `to anon`, so nothing anonymous ever needs to
-- resolve a name in here.

-- ---------------------------------------------------------------------------
-- 2. The graph walk, once per statement
-- ---------------------------------------------------------------------------
-- Each of these is `security definer` so it can read `memberships` and friends without tripping
-- their own policies (which would recurse), `stable` so the planner may hoist it out of the row
-- loop, and `set search_path = ''` so a schema planted on the caller's path cannot redirect a
-- table reference. Every one checks `auth.uid()` itself: a definer function that trusts its
-- argument is a data leak with a helpful interface.
--
-- They return `setof uuid` rather than a boolean taking the row's id, because `x in (select f())`
-- is uncorrelated — Postgres runs it once and hashes the result — whereas `f(x)` is called per
-- row. `(select auth.uid())` inside is the same trick one level down.

create or replace function private.camp_ids_for_caller()
returns setof uuid
language sql
stable
security definer
set search_path = ''
as $$
  select m.camp_id
  from public.memberships m
  where (select auth.uid()) is not null
    and m.account_id = (select auth.uid());
$$;

comment on function private.camp_ids_for_caller() is
  'Camps the calling user holds any membership in. Not callable over REST.';

create or replace function private.admin_camp_ids_for_caller()
returns setof uuid
language sql
stable
security definer
set search_path = ''
as $$
  select m.camp_id
  from public.memberships m
  where (select auth.uid()) is not null
    and m.account_id = (select auth.uid())
    and m.role = 'admin';
$$;

-- A camp nobody has joined yet, created moments ago.
--
-- `SupabaseRepository.createCamp` writes the camp, then its venues, then its courts, and only
-- *then* the membership that makes the author an admin. Steps two and three therefore run while
-- the author has no membership in the camp they just made, and a strict policy would refuse them
-- and leave a half-built camp behind. This is that window and nothing more: zero memberships and
-- under an hour old. The seeded camp is ten hours old, so it is not in here — an unclaimed camp
-- does not stay writable forever just because nobody joined it.
create or replace function private.bootstrappable_camp_ids()
returns setof uuid
language sql
stable
security definer
set search_path = ''
as $$
  select c.id
  from public.camps c
  where (select auth.uid()) is not null
    and c.created_at > now() - interval '1 hour'
    and not exists (select 1 from public.memberships m where m.camp_id = c.id);
$$;

create or replace function private.site_ids_for_caller()
returns setof uuid
language sql
stable
security definer
set search_path = ''
as $$
  select s.id
  from public.sites s
  join public.memberships m on m.camp_id = s.camp_id
  where (select auth.uid()) is not null
    and m.account_id = (select auth.uid());
$$;

create or replace function private.admin_site_ids_for_caller()
returns setof uuid
language sql
stable
security definer
set search_path = ''
as $$
  select s.id
  from public.sites s
  join public.memberships m on m.camp_id = s.camp_id
  where (select auth.uid()) is not null
    and m.account_id = (select auth.uid())
    and m.role = 'admin';
$$;

create or replace function private.bootstrappable_site_ids()
returns setof uuid
language sql
stable
security definer
set search_path = ''
as $$
  select s.id
  from public.sites s
  where s.camp_id in (select private.bootstrappable_camp_ids());
$$;

create or replace function private.group_ids_for_caller()
returns setof uuid
language sql
stable
security definer
set search_path = ''
as $$
  select g.id
  from public.groups g
  join public.sites s on s.id = g.site_id
  join public.memberships m on m.camp_id = s.camp_id
  where (select auth.uid()) is not null
    and m.account_id = (select auth.uid());
$$;

create or replace function private.player_ids_for_caller()
returns setof uuid
language sql
stable
security definer
set search_path = ''
as $$
  select p.id
  from public.players p
  join public.sites s on s.id = p.site_id
  join public.memberships m on m.camp_id = s.camp_id
  where (select auth.uid()) is not null
    and m.account_id = (select auth.uid());
$$;

create or replace function private.coach_ids_for_caller()
returns setof uuid
language sql
stable
security definer
set search_path = ''
as $$
  select c.id
  from public.coaches c
  join public.memberships m on m.camp_id = c.camp_id
  where (select auth.uid()) is not null
    and m.account_id = (select auth.uid());
$$;

-- `create function` grants execute to PUBLIC. Take it back, or the walk is an API endpoint.
revoke execute on all functions in schema private from public;
revoke execute on all functions in schema private from anon, authenticated, service_role;

-- And then hand `authenticated` — and only `authenticated` — the execute bit back, because
-- Postgres checks function permissions inside an RLS policy against the user running the query,
-- not the table owner. Revoking it from `authenticated` does not harden the policy; it makes
-- every policy below fail with `permission denied for function site_ids_for_caller`, verified
-- against this database before this line was written.
--
-- The isolation this was reaching for is still intact, by construction rather than by grant:
--   * PostgREST only exposes `public`, so `POST /rest/v1/rpc/site_ids_for_caller` resolves in the
--     wrong schema and 404s. `private` has no route in.
--   * Every function here takes no arguments and answers only about the caller — that is why they
--     are `..._for_caller()` and not `is_camp_member(camp_id)`. A definer function with a tenant
--     id parameter is a lookup oracle for the whole database if it ever leaks; one with no
--     parameters can only ever repeat what the caller's own policies already allow them to see.
--   * `anon` and `public` keep neither `usage` nor `execute`, so an unauthenticated caller cannot
--     name these functions at all.
grant usage on schema private to authenticated;
grant execute on all functions in schema private to authenticated;

-- ---------------------------------------------------------------------------
-- 3. Indexes for every column a policy filters on
-- ---------------------------------------------------------------------------
-- The rest already existed and are asserted here for the record:
--   camps.id                    camps_pkey
--   memberships.account_id      memberships_account_idx
--   memberships.camp_id         memberships_camp_idx
--   sites.camp_id               sites_camp_idx (camp_id, sort_index)
--   groups.site_id              groups_site_id_name_key (site_id, name)
--   coaches.camp_id             coaches_camp_idx
--   coaches.account_id          coaches_account_idx
--   players.site_id             players_site_id_group_id_idx (site_id, group_id)
--   schedule_blocks.site_id     schedule_blocks_site_day_starts_idx (site_id, day, starts_at)
--   inbox_items.site_id         inbox_items_site_created_idx (site_id, created_at desc)
--   court_assignments.group_id  court_assign_group_idx
--   attendance.player_id        attendance_player_id_day_session_key (player_id, day, session)
--   ratings.player_id           ratings_pkey
--   assessments.player_id       assessments_player_id_created_at_idx (player_id, created_at desc)
--   feedback.player_id          feedback_player_idx
--   feedback.coach_id           feedback_coach_idx
-- and the primary keys the helpers join through: camps_pkey, sites_pkey, groups_pkey,
-- players_pkey, profiles_pkey.
--
-- The only one missing was the age test in `bootstrappable_camp_ids`.

create index if not exists camps_created_at_idx on public.camps (created_at desc);

-- `memberships.role` is deliberately left unindexed, and it is the one column here a policy
-- reads without one. It is never the driving predicate: `admin_camp_ids_for_caller` finds rows by
-- `account_id` first, and `memberships_account_id_camp_id_key` makes that unique per camp, so the
-- role test is a residual check on a handful of rows. A btree over a four-value text column would
-- be write cost for no read.

-- ---------------------------------------------------------------------------
-- 4. Out with the placeholders
-- ---------------------------------------------------------------------------

drop policy if exists mvp_all on public.camps;
drop policy if exists mvp_all on public.memberships;
drop policy if exists mvp_all on public.sites;
drop policy if exists mvp_all on public.groups;
drop policy if exists mvp_all on public.coaches;
drop policy if exists mvp_all on public.players;
drop policy if exists mvp_all on public.schedule_blocks;
drop policy if exists mvp_all on public.inbox_items;
drop policy if exists mvp_all on public.court_assignments;
drop policy if exists mvp_all on public.attendance;
drop policy if exists mvp_all on public.ratings;
drop policy if exists mvp_all on public.assessments;
drop policy if exists mvp_all on public.feedback;

-- `profiles` is left exactly as it is: `profiles_own_row` already says the right thing.

-- ---------------------------------------------------------------------------
-- 5. camps
-- ---------------------------------------------------------------------------
-- Select is the one deliberate exception to "members only", and it is not an oversight.
-- `joinCamp` reads `camps` by invite code *before* the membership exists — that is the whole
-- point of an invite code — so a members-only select would make joining a camp permanently
-- impossible. The cost is that any signed-in user can enumerate camp names and invite codes.
-- Closing it properly needs a `join_camp_by_code(text)` RPC and a client change, which is a Swift
-- edit this migration is not allowed to make. Written down rather than papered over.

drop policy if exists camps_select_signed_in on public.camps;
create policy camps_select_signed_in on public.camps
  for select to authenticated
  using (true);

-- Anybody signed in may start a camp; the membership written immediately after is what makes it
-- theirs.
drop policy if exists camps_insert_signed_in on public.camps;
create policy camps_insert_signed_in on public.camps
  for insert to authenticated
  with check (true);

drop policy if exists camps_update_admin on public.camps;
create policy camps_update_admin on public.camps
  for update to authenticated
  using (id in (select private.admin_camp_ids_for_caller()))
  with check (id in (select private.admin_camp_ids_for_caller()));

drop policy if exists camps_delete_admin on public.camps;
create policy camps_delete_admin on public.camps
  for delete to authenticated
  using (id in (select private.admin_camp_ids_for_caller()));

-- ---------------------------------------------------------------------------
-- 6. memberships
-- ---------------------------------------------------------------------------

drop policy if exists memberships_select_member on public.memberships;
create policy memberships_select_member on public.memberships
  for select to authenticated
  using (
    account_id = (select auth.uid())
    or camp_id in (select private.camp_ids_for_caller())
  );

-- Three ways a membership row is legitimately born:
--   * you joined with an invite code, which hands out `worker` and nothing better;
--   * you just created the camp, and are claiming it as its first admin;
--   * an admin of the camp is adding somebody.
-- The `role = 'worker'` clause is load-bearing: without it, anyone holding an invite code could
-- insert themselves as an admin of a camp they have never seen.
drop policy if exists memberships_insert_self_or_admin on public.memberships;
create policy memberships_insert_self_or_admin on public.memberships
  for insert to authenticated
  with check (
    (
      account_id = (select auth.uid())
      and (
        role = 'worker'
        or camp_id in (select private.bootstrappable_camp_ids())
      )
    )
    or camp_id in (select private.admin_camp_ids_for_caller())
  );

-- Role is authority. Only an admin of the camp may change it — including their own, so a lone
-- admin cannot be locked out, and not their own upward, since they are already at the top.
drop policy if exists memberships_update_admin on public.memberships;
create policy memberships_update_admin on public.memberships
  for update to authenticated
  using (camp_id in (select private.admin_camp_ids_for_caller()))
  with check (camp_id in (select private.admin_camp_ids_for_caller()));

-- Leaving a camp is your own business; removing somebody else is an admin's.
drop policy if exists memberships_delete_self_or_admin on public.memberships;
create policy memberships_delete_self_or_admin on public.memberships
  for delete to authenticated
  using (
    account_id = (select auth.uid())
    or camp_id in (select private.admin_camp_ids_for_caller())
  );

-- ---------------------------------------------------------------------------
-- 7. sites — venues, admin-only to write
-- ---------------------------------------------------------------------------

drop policy if exists sites_select_member on public.sites;
create policy sites_select_member on public.sites
  for select to authenticated
  using (camp_id in (select private.camp_ids_for_caller()));

drop policy if exists sites_insert_admin on public.sites;
create policy sites_insert_admin on public.sites
  for insert to authenticated
  with check (
    camp_id in (select private.admin_camp_ids_for_caller())
    or camp_id in (select private.bootstrappable_camp_ids())
  );

drop policy if exists sites_update_admin on public.sites;
create policy sites_update_admin on public.sites
  for update to authenticated
  using (camp_id in (select private.admin_camp_ids_for_caller()))
  with check (camp_id in (select private.admin_camp_ids_for_caller()));

drop policy if exists sites_delete_admin on public.sites;
create policy sites_delete_admin on public.sites
  for delete to authenticated
  using (camp_id in (select private.admin_camp_ids_for_caller()));

-- ---------------------------------------------------------------------------
-- 8. groups — courts. Adding and removing them is a venue change; renaming and
--    reordering them happens all day, by whoever is running the session.
-- ---------------------------------------------------------------------------

drop policy if exists groups_select_member on public.groups;
create policy groups_select_member on public.groups
  for select to authenticated
  using (site_id in (select private.site_ids_for_caller()));

drop policy if exists groups_insert_admin on public.groups;
create policy groups_insert_admin on public.groups
  for insert to authenticated
  with check (
    site_id in (select private.admin_site_ids_for_caller())
    or site_id in (select private.bootstrappable_site_ids())
  );

drop policy if exists groups_update_member on public.groups;
create policy groups_update_member on public.groups
  for update to authenticated
  using (site_id in (select private.site_ids_for_caller()))
  with check (site_id in (select private.site_ids_for_caller()));

drop policy if exists groups_delete_admin on public.groups;
create policy groups_delete_admin on public.groups
  for delete to authenticated
  using (site_id in (select private.admin_site_ids_for_caller()));

-- ---------------------------------------------------------------------------
-- 9. coaches — the staff roster
-- ---------------------------------------------------------------------------
-- Insert is open to any member because `adoptStaffRow` runs on the way in: a worker who joins
-- with an invite code writes their own staff row. Changing somebody *else's* row — putting them
-- on a court, changing their role, deactivating them — is Setup, and Setup is admin-only.

drop policy if exists coaches_select_member on public.coaches;
create policy coaches_select_member on public.coaches
  for select to authenticated
  using (camp_id in (select private.camp_ids_for_caller()));

drop policy if exists coaches_insert_member on public.coaches;
create policy coaches_insert_member on public.coaches
  for insert to authenticated
  with check (camp_id in (select private.camp_ids_for_caller()));

drop policy if exists coaches_update_self_or_admin on public.coaches;
create policy coaches_update_self_or_admin on public.coaches
  for update to authenticated
  using (
    account_id = (select auth.uid())
    or camp_id in (select private.admin_camp_ids_for_caller())
  )
  with check (
    account_id = (select auth.uid())
    or camp_id in (select private.admin_camp_ids_for_caller())
  );

drop policy if exists coaches_delete_admin on public.coaches;
create policy coaches_delete_admin on public.coaches
  for delete to authenticated
  using (camp_id in (select private.admin_camp_ids_for_caller()));

-- ---------------------------------------------------------------------------
-- 10. The day's work — any member of the camp
-- ---------------------------------------------------------------------------
-- One policy per table rather than four, because the answer is the same for reading and writing:
-- is this row's camp one of yours.

drop policy if exists players_member on public.players;
create policy players_member on public.players
  for all to authenticated
  using (site_id in (select private.site_ids_for_caller()))
  with check (site_id in (select private.site_ids_for_caller()));

drop policy if exists schedule_blocks_member on public.schedule_blocks;
create policy schedule_blocks_member on public.schedule_blocks
  for all to authenticated
  using (site_id in (select private.site_ids_for_caller()))
  with check (site_id in (select private.site_ids_for_caller()));

drop policy if exists inbox_items_member on public.inbox_items;
create policy inbox_items_member on public.inbox_items
  for all to authenticated
  using (site_id in (select private.site_ids_for_caller()))
  with check (site_id in (select private.site_ids_for_caller()));

drop policy if exists court_assignments_member on public.court_assignments;
create policy court_assignments_member on public.court_assignments
  for all to authenticated
  using (group_id in (select private.group_ids_for_caller()))
  with check (group_id in (select private.group_ids_for_caller()));

drop policy if exists attendance_member on public.attendance;
create policy attendance_member on public.attendance
  for all to authenticated
  using (player_id in (select private.player_ids_for_caller()))
  with check (player_id in (select private.player_ids_for_caller()));

drop policy if exists ratings_member on public.ratings;
create policy ratings_member on public.ratings
  for all to authenticated
  using (player_id in (select private.player_ids_for_caller()))
  with check (player_id in (select private.player_ids_for_caller()));

drop policy if exists assessments_member on public.assessments;
create policy assessments_member on public.assessments
  for all to authenticated
  using (player_id in (select private.player_ids_for_caller()))
  with check (player_id in (select private.player_ids_for_caller()));

-- `feedback` is the one row that can hang off either end: a note about a player, or a note from a
-- coach with no player attached. Either anchor will do; a row with neither belongs to no camp and
-- is refused rather than made invisible.
drop policy if exists feedback_member on public.feedback;
create policy feedback_member on public.feedback
  for all to authenticated
  using (
    player_id in (select private.player_ids_for_caller())
    or coach_id in (select private.coach_ids_for_caller())
  )
  with check (
    player_id in (select private.player_ids_for_caller())
    or coach_id in (select private.coach_ids_for_caller())
  );

-- ---------------------------------------------------------------------------
-- WHAT HAPPENS BEFORE ANY USER EXISTS
-- ---------------------------------------------------------------------------
-- `auth.users`, `profiles` and `memberships` are all empty at the time of writing, and nothing
-- above grants `anon` anything. So, concretely:
--
--   * An unauthenticated caller — the publishable key on its own, which is what a stolen key
--     amounts to — reads zero rows from every table and can write none. That is the point.
--   * The app is unaffected at launch: `AppStore` starts at `.signedOut` and every repository
--     call happens after sign-in. There is no anonymous data path to break. Sign-in itself is
--     GoTrue, not PostgREST, so RLS is not in that road.
--   * The first sign-in upserts a `profiles` row under `profiles_own_row`, which already allows
--     it. The camp picker then shows nothing, because the account has no memberships yet.
--   * Entering the seeded camp's invite code, SYC-4821, inserts a `worker` membership and the
--     whole camp — 3 venues, 12 courts, 100 players, their ratings and attendance — appears.
--     Nobody is an admin of that camp until an admin is promoted; promote the first one with the
--     service role key:
--
--       update public.memberships set role = 'admin', role_label = null
--        where camp_id = '4f8ab779-f077-4841-a11a-a8369ae5f3a2';
--
--     Until then Setup is read-only for everyone, which is a locked door rather than a broken
--     screen.
--   * One pre-existing site, `Sunset`, has a null `camp_id` and so belongs to no camp and is
--     visible to nobody. It has no players, groups, schedule blocks or inbox items, and the app
--     never listed it anyway — `memberships(forAccount:)` selects sites by `camp_id in (…)`.
--     Give it a camp or delete it; it is dead weight either way.
