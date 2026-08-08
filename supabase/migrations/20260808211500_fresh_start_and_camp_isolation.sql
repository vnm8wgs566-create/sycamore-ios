--
--  Fresh start: camp isolation, least privilege, and a profile for every sign-in.
--
--  Written while turning Sign In with Apple on, which is the first time real accounts will exist
--  in this project. Everything below is something that was survivable while the only rows were
--  seed rows and the only reader was the person who wrote them, and stops being survivable the
--  moment a stranger can hold a session.
--
--  Eight changes, in dependency order — the foreign keys in section 5 are what let section 6
--  delete anything, and section 6 is what lets section 7 declare `camp_id` not null.
--
--  1. A signed-in stranger could join any camp as a worker, and read it.
--  2. `profiles` was reachable by the `public` role rather than `authenticated`.
--  3. `anon` held full DML on every table. Only RLS stood in front of it.
--  4. Nothing created a `profiles` row, and `memberships.account_id` requires one.
--  5. No camp could ever be deleted, so `camps_delete_admin` was a policy that could not fire.
--  6. The seeded demo camp and one orphaned venue are removed.
--  7. Venue names were unique across the whole project rather than within a camp.
--  8. `join_camp_by_code` is documented as deliberately exposed, since section 1 makes it the
--     only way in and the linter will keep flagging it.
--
--  What is deliberately NOT here: `alter table … force row level security`. Forcing RLS applies
--  policies to the table owner too, and in this project the owner is `postgres` — the role every
--  migration and every SQL-editor query runs as. Turning it on would make section 6's own DELETE
--  silently match nothing. `authenticated` and `anon` are not owners, so RLS already applies to
--  them; forcing it buys nothing and breaks the migration path.
--

-- ---------------------------------------------------------------------------------------------
-- 1. Cross-camp isolation: a worker cannot enrol themselves.
-- ---------------------------------------------------------------------------------------------
--
-- `memberships_insert_self_or_admin` read, in the arm that mattered:
--
--     account_id = auth.uid() and role = 'worker'
--
-- with no test on `camp_id` at all. Anyone holding a session and a camp's UUID could insert
-- themselves as a worker into that camp and immediately read its players, ratings, attendance,
-- assessments and feedback — every one of those policies grants on membership alone.
--
-- The UUID is not the secret that sentence needs it to be. `join_camp_by_code` returns it to
-- every coach who ever pastes an invite code, and a coach keeps it after they leave: removing a
-- worker deletes their membership row and nothing else, so until now "remove from camp" was
-- undone by one POST. That is the case that makes this a hole rather than an untidiness.
--
-- The arm is also dead weight as far as the app is concerned. `SupabaseRepository` writes
-- `memberships` in exactly one place — `createCamp`, inserting the creator as `admin` into a camp
-- made seconds earlier, which the `bootstrappable_camp_ids` arm already covers. Joining a camp
-- that already exists goes through `public.join_camp_by_code`, which is `security definer`,
-- checks the invite code against the `^[A-Z]{3}-[0-9]{4}$` shape and inserts the row itself. So
-- removing this changes no path the client takes; it removes a path only an attacker takes.
--
-- What survives: bootstrapping a camp you have just created, and an admin adding somebody to a
-- camp they administer.
drop policy if exists memberships_insert_self_or_admin on public.memberships;

create policy memberships_insert_self_or_admin on public.memberships
    for insert to authenticated
    with check (
        -- Claiming the camp you just made. `bootstrappable_camp_ids` is the narrow window:
        -- created in the last hour, and still with no members at all.
        (
            account_id = (select auth.uid())
            and camp_id in (select private.bootstrappable_camp_ids())
        )
        -- An admin adding anyone to a camp they administer.
        or camp_id in (select private.admin_camp_ids_for_caller())
    );

-- ---------------------------------------------------------------------------------------------
-- 2. `profiles` belongs to signed-in callers, not to `public`.
-- ---------------------------------------------------------------------------------------------
--
-- `profiles_own_row` was granted `to public`, which includes `anon`. It was not exploitable —
-- `auth.uid()` is null without a JWT and `null = id` is null, so the policy matched nothing — but
-- "not exploitable because of how three-valued logic happens to work" is a thin thing to rest on,
-- and it is the only policy in the project that names a role other than `authenticated`.
drop policy if exists profiles_own_row on public.profiles;

create policy profiles_own_row on public.profiles
    for all to authenticated
    using ((select auth.uid()) = id)
    with check ((select auth.uid()) = id);

-- ---------------------------------------------------------------------------------------------
-- 3. Least privilege: `anon` loses the grants it never used.
-- ---------------------------------------------------------------------------------------------
--
-- Every table carried `anon: SELECT, INSERT, UPDATE, DELETE`. RLS held the line, because every
-- policy in the project is `to authenticated` and an anonymous caller matches none of them — the
-- probe run before writing this confirmed `anon` reads 0 rows from `players`, `today_courts`,
-- `roster_today` and `player_scores`. But that means one policy written `to public` by mistake,
-- or one table created without a policy, is a full public export rather than a bug. The grant is
-- the blast radius; RLS is the safety catch. Remove the grant.
--
-- Nothing anonymous talks to PostgREST. Sign-in, verification and the Apple token exchange are
-- all GoTrue endpoints under `/auth/v1`, which do not care about table privileges, and the app
-- reaches `/rest/v1` only after it holds a session.
--
-- `usage on schema public` is left in place on purpose. Revoking it changes PostgREST's answer
-- for an anonymous caller from a clean row-level empty to a schema-level error, and the schema
-- cache is built by `authenticator`, not by `anon` — a change with a real chance of breaking
-- something and no privilege left to win.
revoke all on all tables in schema public from anon;
revoke all on all sequences in schema public from anon;
revoke all on all functions in schema public from anon;

-- Future tables would otherwise arrive with the same grants. `alter default privileges` is
-- per-grantor, which this project has been caught by before (see 20260805152045), so this fixes
-- the defaults for `postgres` — the role migrations run as, and therefore the role that will own
-- every table created from here.
alter default privileges for role postgres in schema public revoke all on tables from anon;
alter default privileges for role postgres in schema public revoke all on sequences from anon;
alter default privileges for role postgres in schema public revoke all on functions from anon;

-- ---------------------------------------------------------------------------------------------
-- 4. Every sign-in gets a profile, without the client having to remember.
-- ---------------------------------------------------------------------------------------------
--
-- `memberships.account_id` references `profiles.id`, and `profiles.id` references `auth.users.id`.
-- Nothing created the middle row: there was no trigger on `auth.users`, so a brand-new account
-- existed in `auth` and nowhere else until `SupabaseRepository.adoptProfile` upserted it.
--
-- That upsert is real and it runs on every sign-in path, so this is a safety net rather than a
-- fix. It is worth having because of what the gap looks like when it opens: if the profile write
-- is the request that fails — the network drops between the token exchange and the upsert, which
-- is a two-request window on a phone — the person is left holding a valid session attached to no
-- profile. Every subsequent write dies on a foreign key, `createCamp` included, and signing out
-- and back in is the only cure. Apple sign-in makes that window matter more, because it is the
-- path with no email round trip to slow it down.
--
-- `on conflict do nothing`, so the client's upsert and this trigger cannot fight: whichever runs
-- first writes the row, the second is a no-op, and `adoptProfile` still owns the email.
--
-- `coalesce(new.email, '')` because `profiles.email` is `not null` and Apple does not always hand
-- GoTrue an address — "Hide My Email" supplies a relay, but a token carrying no email claim at
-- all would otherwise abort the signup inside GoTrue's own transaction, which surfaces to the
-- phone as a failed sign-in with nothing to act on. An empty string is recoverable; a failed
-- signup is not.
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
    insert into public.profiles (id, email)
    values (new.id, coalesce(new.email, ''))
    on conflict (id) do nothing;
    return new;
end;
$$;

-- `create function` grants execute to PUBLIC. This one is reachable only as a trigger and must
-- not be callable over the API — the same revoke the RLS helpers in `private` already carry, for
-- the same reason.
revoke all on function public.handle_new_user() from public, anon, authenticated;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
    after insert on auth.users
    for each row execute function public.handle_new_user();

-- ---------------------------------------------------------------------------------------------
-- 5. A camp can be deleted.
-- ---------------------------------------------------------------------------------------------
--
-- `camps_delete_admin` has existed since 20260806013152 and could never have succeeded. Deleting
-- a camp cascades to `sites`, and `sites` cascades to `groups` — but `players.site_id` and
-- `players.group_id` were plain references with no action, so the cascade reached them and the
-- whole delete rolled back with a foreign key violation. The same is true of every reference to
-- `coaches` and `groups` left at the default.
--
-- The distinction the fixes below draw is between a row that *is* part of the thing being deleted
-- and a row that merely *points at* it:
--
--   * `players` belong to the venue. Deleting the camp deletes them — cascade.
--   * `assessments.opponent_id` names the other kid in a comparison; `attendance.noted_by`,
--     `ratings.last_by`, `feedback.coach_id` and `assessments.coach_id` name who did something.
--     Those are annotations. When the row they point at goes, the fact stays and the pointer
--     empties — set null. `feedback.player_id` already made exactly this choice, which is the
--     precedent the rest now follow.
--   * `assessments.group_id` names the court an assessment happened on. Same argument: the
--     assessment outlives the court arrangement.
--
-- Every column moved to `set null` is already nullable, so no data is invented to satisfy this.
alter table public.players drop constraint if exists players_site_id_fkey;
alter table public.players add constraint players_site_id_fkey
    foreign key (site_id) references public.sites(id) on delete cascade;

alter table public.players drop constraint if exists players_group_id_fkey;
alter table public.players add constraint players_group_id_fkey
    foreign key (group_id) references public.groups(id) on delete set null;

alter table public.assessments drop constraint if exists assessments_opponent_id_fkey;
alter table public.assessments add constraint assessments_opponent_id_fkey
    foreign key (opponent_id) references public.players(id) on delete set null;

alter table public.assessments drop constraint if exists assessments_group_id_fkey;
alter table public.assessments add constraint assessments_group_id_fkey
    foreign key (group_id) references public.groups(id) on delete set null;

alter table public.assessments drop constraint if exists assessments_coach_id_fkey;
alter table public.assessments add constraint assessments_coach_id_fkey
    foreign key (coach_id) references public.coaches(id) on delete set null;

alter table public.attendance drop constraint if exists attendance_noted_by_fkey;
alter table public.attendance add constraint attendance_noted_by_fkey
    foreign key (noted_by) references public.coaches(id) on delete set null;

alter table public.ratings drop constraint if exists ratings_last_by_fkey;
alter table public.ratings add constraint ratings_last_by_fkey
    foreign key (last_by) references public.coaches(id) on delete set null;

alter table public.feedback drop constraint if exists feedback_coach_id_fkey;
alter table public.feedback add constraint feedback_coach_id_fkey
    foreign key (coach_id) references public.coaches(id) on delete set null;

-- ---------------------------------------------------------------------------------------------
-- 6. The demo camp and the orphaned venue go.
-- ---------------------------------------------------------------------------------------------
--
-- 20260805143540 seeded "UCLA Tennis Camp" — 100 players, 138 attendance rows, 14 coaches, 12
-- groups, 10 schedule blocks. It was built to give the section 8 screens something to draw
-- against before anyone could sign in, and it has no owner: `auth.users` is empty, so no account
-- can reach any of it. The rows are unreachable clutter that would sit under the first real camp.
--
-- Scoped to the invite code rather than written as `truncate`, and that is the point. This file
-- will be replayed by `supabase db reset` and by any future environment built from this history.
-- A truncate would empty whatever it found there; naming the seed's own invite code deletes the
-- seed and only the seed. Now that section 5 has made the cascade complete, this one statement
-- reaches every table.
delete from public.camps where invite_code = 'SYC-4821';

-- A venue called "Sunset" predates `sites.camp_id` (added by 20260805141707) and never got one.
-- It carries no players, groups, blocks or inbox rows. With a null `camp_id` it is invisible to
-- `private.site_ids_for_caller`, which reaches a site by joining `memberships` on `camp_id` — so
-- it is not merely unused, it is unreachable by any account that could ever exist. Section 7
-- cannot declare the column `not null` while it is here.
delete from public.sites where camp_id is null;

-- Belt to the cascades' braces, and a no-op on a healthy database: `coaches.camp_id` is nullable,
-- so a coach row is the one child that could in principle outlive the camp it belongs to.
delete from public.coaches c
where c.camp_id is null
   or not exists (select 1 from public.camps camp where camp.id = c.camp_id);

-- ---------------------------------------------------------------------------------------------
-- 7. Venue names are unique within a camp, not across the project.
-- ---------------------------------------------------------------------------------------------
--
-- `sites_name_key` was `unique (name)` — globally. Two camps could not both have a venue called
-- "Main Courts", and the second one to try got a constraint violation naming a row it is not
-- allowed to read. `groups` had this right all along (`unique (site_id, name)`); `sites` was the
-- odd one out.
--
-- It is a leak as well as a bug: a unique violation is an oracle. Create a camp, try venue names,
-- and the errors tell you which ones exist somewhere else in the project. For a camp whose venues
-- are named after the streets they are on, that is the camp's location.
alter table public.sites drop constraint if exists sites_name_key;

-- Nulls are distinct in a unique index, so an orphan site would sit outside the new constraint
-- entirely. Section 6 removed the only one; the column can now say what every write path already
-- does — `SupabaseRepository.insertSite` takes `campID` as a parameter and always sets it.
alter table public.sites alter column camp_id set not null;

alter table public.sites add constraint sites_camp_id_name_key unique (camp_id, name);

-- ---------------------------------------------------------------------------------------------
-- 8. Say out loud that `join_camp_by_code` is meant to be reachable.
-- ---------------------------------------------------------------------------------------------
--
-- Supabase's linter flags it (0029, "Signed-In Users Can Execute SECURITY DEFINER Function") and
-- will go on flagging it, because from the outside a definer function on the API surface is
-- indistinguishable from one left exposed by accident. Section 1 makes it more load-bearing, not
-- less: with the unrestricted self-insert gone, this function is now the *only* way anyone joins
-- a camp they did not create, and it has to be `security definer` to do it — inserting the
-- membership is precisely the thing the caller's own policy refuses.
--
-- What makes that safe is the body, not the grant: it returns early unless `auth.uid()` is
-- present, it normalises and shape-checks the code against `^[A-Z]{3}-[0-9]{4}$` before touching
-- a table, it hands out `worker` and never `admin`, and `on conflict do nothing` stops a second
-- paste from demoting an existing admin. `anon` cannot reach it at all.
--
-- Left as debt, deliberately, because it is a change of a different kind: the code is three
-- letters derived from the camp's name plus four digits, so an attacker who knows the name is
-- guessing one of ten thousand, and nothing here rate-limits them. Closing that means expiring
-- codes or counting attempts, and it wants its own migration.
comment on function public.join_camp_by_code(text) is
    'Intentionally executable by authenticated: the only path to joining a camp you did not '
    'create. Definer by necessity — the caller''s own RLS forbids the membership insert. Checks '
    'auth.uid(), shape-checks the code, grants worker only. See migration 20260808211500 §8.';
