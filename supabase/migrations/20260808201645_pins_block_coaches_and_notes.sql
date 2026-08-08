-- Three things the design asks for that the schema could not say, and one policy that was
-- wider than any screen it serves.
--
--   * A pinned message. `8r` holds it at the top of the Inbox and Overview banners it above the
--     courts. Only an admin may put one there or take it down.
--   * A block's notes — the admin's description of what the activity actually is, which is the
--     same `inbox_items` row `20260806031106` gave `schedule_block_id` to, now with an author
--     rule attached.
--   * Who is running a block. That is a set of coaches, so it is a table.
--
-- Conventions follow the migrations before this one: `timestamptz` audit columns, columns added
-- additively with a default so every seeded row keeps reading as it did, `if not exists` and
-- `drop policy if exists` throughout so the file is re-runnable end to end, and a reason written
-- down beside every choice — including the one place below that deliberately breaks the schema's
-- own primary-key convention and says so rather than letting it look like an oversight.

-- ---------------------------------------------------------------------------
-- 1. inbox_items.pinned — a claim the row makes, not a shape it happens to have
-- ---------------------------------------------------------------------------
-- Pinned used to be *inferred*, in Swift, from `kind == .note && groupID == nil`. That is two
-- rules pretending to be one, and the second is backwards: attaching a note to a court
-- *un-pinned* it, so the moment somebody said which court the loose net was on, the banner
-- announcing it vanished.
--
-- A camp-wide note and a pinned note are different claims, and a row is entitled to make
-- either, both or neither. So it is stored. The Swift half — `InboxItem.pinned` in
-- `Sycamore/Models/SectionEight.swift` — has already landed; this is the column it reads.
--
-- Additive with a constant default, in the style of `20260806031106_section8_model_gaps.sql`.
-- Postgres 11 and later record that default in the catalogue instead of rewriting the heap, so
-- this is metadata-only over the eleven seeded inbox rows and takes no long lock.
--
-- No CHECK ties `pinned` to `kind`. `20260806031106:75-77` made exactly this call for
-- `schedule_block_id` — left "nullable and unconstrained by `kind`", because "narrowing that to
-- notes would be a decision the design does not make" — and the same holds here. An admin who
-- wants a `needs_action` row held at the top of the Inbox is not doing anything incoherent.

alter table public.inbox_items add column if not exists pinned boolean not null default false;

comment on column public.inbox_items.pinned is
  'Held at the top of the Inbox and drawn on Overview as the banner. Admin-only to write; see '
  'inbox_items_insert_member and friends. Never inferred from kind or group_id.';

-- Modelled on `inbox_items_needs_action_idx` (`20260805074039:88-90`): same key, a different
-- `where`. Partial for the same reason that one is — the rows it excludes are the overwhelming
-- majority once a camp has been running a while, and this index is read on every Overview open.
-- A query that also says `and not resolved` still uses it, with the resolved test as a residual
-- over the handful of rows that survive `pinned`.
create index if not exists inbox_items_pinned_idx
  on public.inbox_items (site_id, created_at desc)
  where pinned;

-- NOT BACKFILLED, deliberately, and for two reasons.
--
-- The only rule available to backfill from is the Swift one this column replaces, and it was
-- wrong. Run it over the seed and it pins "Shade tent is up" and "Two nut allergies" — notes
-- with no group — while leaving the row literally titled "Nass pinned a note" unpinned, because
-- that one names Group 4. Writing a known bug into the data is worse than starting empty;
-- `20260806031106:19-22` made the same call about `players.last_name`, where "C" is not "Chu".
--
-- And nobody is an admin of the seeded camp until one is promoted with the service role key
-- (`20260806031119:195-198`), so a row pinned here would be a banner no user of the app could
-- take down. Every camp starts with nothing pinned, which is a true statement about it.

-- ---------------------------------------------------------------------------
-- 2. inbox_items — one policy becomes four, and three of them grow an admin test
-- ---------------------------------------------------------------------------
-- `20260806013152_real_rls.sql:456-460` gave this table a single `for all` policy: any member of
-- the camp may read and write any inbox row at their venues. That was right when every inbox row
-- was somebody's note about the morning. It is no longer right, because two kinds of row are now
-- an admin's word rather than anyone's:
--
--   * a pinned row — the thing the whole camp is told when it opens the app;
--   * a note attached to a block — the "notes section where the admin can have a description of
--     the activity", which is what `8k`'s note footer and `8l`'s notes card draw.
--
-- Reading is unchanged and stays one predicate: every member of the camp reads everything at
-- their venues, including the rows they may not write. A pinned note nobody could read would be
-- a strange sort of pin.
--
-- ON UPDATE THE ADMIN TEST GOES IN BOTH `using` AND `with check`, AND THAT IS NOT BELT AND
-- BRACES. `using` is evaluated against the row as it stands; `with check` against the row as it
-- would become. Each half closes one direction and neither closes the other:
--
--   * without the `with check` half, a non-admin takes a plain unattached note (so `using`
--     passes, it is an ordinary row) and PATCHes `pinned = true` — or a `schedule_block_id` —
--     onto it. They cannot create an admin's row, so they edit one into existence instead.
--   * without the `using` half, a non-admin takes an admin's pinned note and PATCHes `pinned =
--     false`, or detaches it from its block. The new row is ordinary, so `with check` passes,
--     and the pin is gone.
--
-- THE BLOCK-NOTE TEST IS `kind = 'note' and schedule_block_id is not null`, NOT MERELY "HAS A
-- BLOCK ID". `20260806031106:75-77` left that column unconstrained by `kind` on purpose, so a
-- `needs_action` row may name a block, and the seed has exactly such a row: "LATC is 2 coaches
-- short" / "10:45 match play · unassigned" (`20260805143540:383`), whose block the seed states it
-- mirrored the whole LATC schedule to provide (`20260805143540:324-325`). Gating every
-- block-tagged row on admin would make raising that row an admin's job, and a coach standing on
-- an unstaffed court at 10:45 is the entire reason it exists. Raising a problem about a block is
-- running-the-day work; writing the block's description is not.
--
-- FOUR POLICIES, NOT ONE. `20260806031119:127-128` records that this schema keeps one policy per
-- command per table so Supabase's `multiple_permissive_policies` advisor stays quiet. Four
-- policies across four *distinct* commands satisfies that exactly — select, insert, update and
-- delete each end up with one permissive policy, which is what the advisor counts. Four
-- permissive policies on the same command would not, and adding a second `for all` policy
-- alongside these would land on all four commands at once and trip it four times over.
--
-- `private.admin_site_ids_for_caller()` already exists (`real_rls.sql:119-132`) and is what
-- `sites_insert_admin` (`:356-362`) and `sites_update_admin` (`:364-368`) use; this copies their
-- shape. Each expression below is written as one admin-or-ordinary test rather than as two
-- separate admin clauses, so the helper is named once per expression and the planner builds one
-- uncorrelated InitPlan for it instead of two — which is the whole reason these helpers return
-- `setof uuid` (`real_rls.sql:49-51`) rather than a boolean taking the row's id.
--
-- Every column these filter on is indexed already, checked rather than assumed:
-- `inbox_items.site_id` leads `inbox_items_site_created_idx`, and `pinned`, `kind` and
-- `schedule_block_id` are residual tests on the rows that survive it, not driving predicates.

drop policy if exists inbox_items_member on public.inbox_items;

drop policy if exists inbox_items_select_member on public.inbox_items;
create policy inbox_items_select_member on public.inbox_items
  for select to authenticated
  using (site_id in (select private.site_ids_for_caller()));

drop policy if exists inbox_items_insert_member on public.inbox_items;
create policy inbox_items_insert_member on public.inbox_items
  for insert to authenticated
  with check (
    site_id in (select private.site_ids_for_caller())
    and (
      site_id in (select private.admin_site_ids_for_caller())
      or (
        not pinned
        and not (kind = 'note' and schedule_block_id is not null)
      )
    )
  );

drop policy if exists inbox_items_update_member on public.inbox_items;
create policy inbox_items_update_member on public.inbox_items
  for update to authenticated
  using (
    site_id in (select private.site_ids_for_caller())
    and (
      site_id in (select private.admin_site_ids_for_caller())
      or (
        not pinned
        and not (kind = 'note' and schedule_block_id is not null)
      )
    )
  )
  with check (
    site_id in (select private.site_ids_for_caller())
    and (
      site_id in (select private.admin_site_ids_for_caller())
      or (
        not pinned
        and not (kind = 'note' and schedule_block_id is not null)
      )
    )
  );

-- Delete has no `with check` — there is no new row — so `using` carries the whole rule, and it
-- is the same rule: a member may clear the ordinary rows at their venues, an admin may clear
-- anything at theirs, and taking down a pin is therefore an admin's act in both directions.
drop policy if exists inbox_items_delete_member on public.inbox_items;
create policy inbox_items_delete_member on public.inbox_items
  for delete to authenticated
  using (
    site_id in (select private.site_ids_for_caller())
    and (
      site_id in (select private.admin_site_ids_for_caller())
      or (
        not pinned
        and not (kind = 'note' and schedule_block_id is not null)
      )
    )
  );

-- `pinned` is `not null` and `kind` is `not null`, so neither test can evaluate to NULL and be
-- read as a refusal by accident. `schedule_block_id is not null` is a boolean either way. This
-- matters more than it looks: a policy clause that answers NULL is a denial, and a denial nobody
-- intended is the kind of bug that only shows up on the one row that has a null in it.

-- ---------------------------------------------------------------------------
-- 3. private.schedule_block_ids_for_caller()
-- ---------------------------------------------------------------------------
-- The join table in section 4 has no `site_id` of its own — the row *is* a pair of foreign keys
-- — so its policy cannot ask the question directly and needs a helper, exactly as
-- `court_assignments_member` needs `private.group_ids_for_caller()` (`real_rls.sql:462-466`).
-- This is that function with `schedule_blocks b` in place of `groups g` and `b.site_id` in place
-- of `g.site_id`; the walk to the camp is identical, because a block hangs off a site the same
-- way a group does.
--
-- All four properties `real_rls.sql:43-51` argues for are kept, and each earns its place:
--   * `security definer`, so reading `memberships` does not recurse through `memberships`' own
--     policy — which is what a plain invoker function would do, and it would not terminate;
--   * `stable`, so the planner may hoist the call out of the row loop instead of calling it once
--     per candidate row;
--   * `set search_path = ''`, so a schema planted on the caller's path cannot make
--     `schedule_blocks` mean something else — every reference below is schema-qualified because
--     of it;
--   * `setof uuid` and no arguments, so `x in (select f())` is uncorrelated and Postgres runs it
--     once and hashes the result. No arguments is also the security half: a definer function
--     with a tenant id parameter is a lookup oracle, one with none can only ever repeat what the
--     caller's own policies already allow.
--
-- It checks `auth.uid()` itself rather than trusting the grant to be the only door, for the
-- reason `real_rls.sql:46-47` gives: a definer function that trusts its caller is a data leak
-- with a helpful interface.
--
-- Indexed end to end, checked rather than assumed: `schedule_blocks.site_id` leads
-- `schedule_blocks_site_day_starts_idx`, `sites.id` is `sites_pkey`, and `memberships` is found
-- by `memberships_account_idx` and joined by `memberships_camp_idx`. Nothing new is needed.

create or replace function private.schedule_block_ids_for_caller()
returns setof uuid
language sql
stable
security definer
set search_path = ''
as $$
  select b.id
  from public.schedule_blocks b
  join public.sites s on s.id = b.site_id
  join public.memberships m on m.camp_id = s.camp_id
  where (select auth.uid()) is not null
    and m.account_id = (select auth.uid());
$$;

comment on function private.schedule_block_ids_for_caller() is
  'Schedule blocks at venues of camps the calling user holds a membership in. Not callable over '
  'REST.';

-- THE TRAP, and it fails at query time rather than here. `create function` grants execute to
-- PUBLIC. `real_rls.sql:190-210` revoked that and handed the bit back to `authenticated` — but
-- that ran once, over the functions that existed then, as `... on all functions in schema
-- private`. A function created afterwards is not covered by it, so both lines are repeated here
-- for this one.
--
-- The grant is not optional and is not a loosening. `real_rls.sql:196-198` records it as
-- verified against this database: Postgres checks function permissions inside a policy against
-- the role running the query, not the table owner, so without it every policy naming this
-- function fails with `permission denied for function schedule_block_ids_for_caller`. Revoking
-- from `authenticated` would not harden anything; it would only break section 4.
revoke execute on function private.schedule_block_ids_for_caller() from public, anon, service_role;
grant  execute on function private.schedule_block_ids_for_caller() to authenticated;

-- ---------------------------------------------------------------------------
-- 4. schedule_block_coaches — who is running this block
-- ---------------------------------------------------------------------------
-- "Logistics (date, where, coach/coaches)". Date and venue a block already carries; coaches is
-- the plural that has nowhere to go. `coaches.site_id` says where somebody is based and
-- `court_assignments` says which court they have this morning; neither says who is running the
-- 10:45 match play, and `schedule_blocks.status = 'needs_coach'` is the app complaining about a
-- gap it cannot otherwise describe. `ScheduleBlock.coachIDs` in
-- `Sycamore/Models/SectionEight.swift:90` is the Swift side of this table and already exists.
--
-- COMPOSITE PRIMARY KEY, NOT A SURROGATE UUID, and this deviates from the convention
-- `20260805074039:11-13` sets for the whole schema ("uuid primary keys defaulting to
-- `gen_random_uuid()`"). Said out loud so a later reader does not read it as an oversight and
-- "fix" it. The row *is* the pair: there is no such thing as two different assignments of the
-- same coach to the same block. A `gen_random_uuid()` id would still need a
-- `unique (block_id, coach_id)` beside it to say so, which is the index below wearing a second
-- hat, so the surrogate buys nothing and costs 16 bytes and an index per row. It also makes the
-- delete-then-insert rewrite the client does when a block's staffing changes incapable of
-- leaving duplicates behind, rather than merely unlikely to.
--
-- BOTH FOREIGN KEYS CASCADE, which inverts the reasoning at `20260805074039:64-66`, where
-- `inbox_items.actor_id` is `on delete set null` because "a coach leaving the camp must not
-- silently delete the history of what they did". An assignment is not history. It is a claim
-- about who is running a block *now*, and a claim about a coach who no longer exists is not a
-- record worth keeping — it is a name the Schedule screen would draw with nothing behind it.
-- Delete the block and its staffing goes with it for the same reason.

create table if not exists public.schedule_block_coaches (
  block_id   uuid not null references public.schedule_blocks (id) on delete cascade,
  coach_id   uuid not null references public.coaches (id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (block_id, coach_id)
);

comment on table public.schedule_block_coaches is
  'Which coaches are running which schedule block. The row is the pair, hence the composite key.';
comment on column public.schedule_block_coaches.created_at is
  'When the assignment was made. Not a history: the row is deleted when the assignment ends.';

-- TWO INDEXES, NOT ONE. The primary key gives a btree on `(block_id, coach_id)`, which serves
-- every `block_id = $1` lookup the Schedule screen makes and the cascade from `schedule_blocks`.
-- A leading-column index cannot drive `coach_id = $1`, so `coaches`' own cascade — every
-- `removeStaff`, every camp deletion fanning out through it — would scan this table under a
-- lock. That is the rule this schema has already stated twice: `20260805074039:43-44`
-- ("Postgres does not index FK columns for you, and an unindexed one makes `on delete cascade`
-- scan the whole table") and `20260805141707:134-135`. It reads for "which blocks is this coach
-- on today", too, which is the same question the coach's own screen asks.
create index if not exists schedule_block_coaches_coach_idx
  on public.schedule_block_coaches (coach_id);

-- This migration adds no CHECK constraint. The constraints a block editor has to mirror are
-- `schedule_blocks`' own — `title` 1–80, `detail` ≤ 160, `status` in three values, and
-- `ends_at > starts_at` — and their Swift mirror is
-- `Sycamore/Features/Schedule/BlockEditorDraft.swift`. Named here so the pair stays findable: a
-- CHECK added to either side without the other is a form that either accepts what the database
-- refuses, or refuses what it would have accepted.

alter table public.schedule_block_coaches enable row level security;

-- `and`, NOT `or`, and this is the one place to deviate from the nearest exemplar.
-- `feedback_member` (`real_rls.sql:489-499`) uses `or` because a feedback row legitimately hangs
-- off *either* end — a note about a player, or a note from a coach with no player attached. Here
-- both ends must hold. With `or`, a member of camp A creates a row naming one of their own
-- blocks and any coach uuid they can name, and a uuid from camp B satisfies the policy through
-- the block half alone. That is not a leak of rows so much as a write into a camp they are not
-- in, and it would surface as a stranger's name on somebody else's schedule.
--
-- `private.coach_ids_for_caller()` (`real_rls.sql:176-188`) is camp-scoped rather than
-- site-scoped, and that is deliberate here rather than merely inherited: `coaches.is_roaming`
-- exists and `coaches.site_id` is nullable, so a coach covering a block at the camp's other
-- venue is an ordinary Tuesday, not an anomaly to be refused.
--
-- MEMBER-WRITABLE, NOT ADMIN-ONLY. `schedule_blocks` itself is member-writable
-- (`real_rls.sql:450-454`), and a join table stricter than the table it hangs off would mean a
-- coach may delete the entire block but not remove one name from it. Assigning cover when
-- somebody calls in sick is running-the-day work, which is the class `real_rls.sql:17-18`
-- already lists — attendance, ratings, the ladder, the inbox, moving players between courts.
--
-- IF BLOCK EDITING IS EVER MADE ADMIN-ONLY, THIS POLICY AND `schedule_blocks_member` MUST CHANGE
-- TOGETHER. Changing one alone is incoherent in either direction: admin-only blocks with
-- member-writable staffing lets a worker rewrite who is running a block they cannot touch, and
-- the reverse is the delete-the-block-but-not-the-name absurdity above.
drop policy if exists schedule_block_coaches_member on public.schedule_block_coaches;
create policy schedule_block_coaches_member on public.schedule_block_coaches
  for all to authenticated
  using (
    block_id in (select private.schedule_block_ids_for_caller())
    and coach_id in (select private.coach_ids_for_caller())
  )
  with check (
    block_id in (select private.schedule_block_ids_for_caller())
    and coach_id in (select private.coach_ids_for_caller())
  );

-- ---------------------------------------------------------------------------
-- 5. Grants — redundant by design
-- ---------------------------------------------------------------------------
-- `20260805152045:47-48` set
--
--     alter default privileges in schema public
--       grant select, insert, update, delete on tables to anon, authenticated;
--
-- so a table created in `public` after that line *should* already be covered, and the grant
-- below should be a no-op. It is written anyway, because default privileges apply only to
-- objects created by the role that ran that ALTER. Applied by a different role — the CLI's
-- migration role rather than whoever ran that file, a `psql` session as the owner, a restore —
-- the new table inherits nothing, sits at `REFERENCES, TRIGGER, TRUNCATE`, and the app is
-- answered `42501 permission denied`. That is precisely the failure `20260805152045:1-12` exists
-- to document, and it cost a debugging session that one line is cheaper than.
--
-- `truncate` is deliberately not granted, matching `20260805152045:18-19`: it is a footgun
-- nobody needs over a REST API. `anon` is named because the file it copies names it, and because
-- the grant hands `anon` no row it could reach — the only policy on this table is
-- `to authenticated`, so an anonymous caller matches nothing and reads nothing. RLS narrows what
-- a role may see; the grant is what lets it reach the table at all.
--
-- `inbox_items` already holds its grant from `20260805152045:26` and needs nothing here: adding
-- a column does not change a table-level privilege.

grant select, insert, update, delete on public.schedule_block_coaches to anon, authenticated;

-- NO VIEW, and not for want of one being convenient. A `block_coaches` view joining names onto
-- ids is exactly the shape `today_courts` has, and `today_courts` is the cautionary tale sitting
-- in this schema already: `20260806031119:165-168` and `20260805152045:5-7` both record that a
-- `drop view … create view` reset its grants, `authenticated` lost `select`, and the app has been
-- answered `42501` on it ever since — which is why `SupabaseRepository+SectionEight.courts`
-- assembles four requests by hand instead. PostgREST reads this table with an embedded join
-- (`schedule_block_coaches?select=coach_id,coaches(name)`), which needs no view and no grant
-- beyond the one above.
--
-- If a view is ever added here regardless, `with (security_invoker = true)` is mandatory.
-- `20260805141707:152-155` flags the definer-rights version at ERROR: such a view runs with its
-- creator's rights and ignores the caller's RLS entirely, so a definer view over `inbox_items`
-- would hand every camp's Inbox — pinned notes, block notes and all — to everyone who could
-- select from it.

-- ---------------------------------------------------------------------------
-- WHAT CHANGES THE MOMENT THIS APPLIES
-- ---------------------------------------------------------------------------
--   * An unauthenticated caller still gets nothing. Every policy here is `to authenticated`,
--     `anon` matches none of them, and `private` grants it neither `usage` nor `execute`.
--   * A member who is not an admin keeps everything they had except two things: they can no
--     longer pin or unpin, and they can no longer write a note that names a block. They still
--     *read* both. Raising a `needs_action` row about a block — "LATC is 2 coaches short" — is
--     untouched, which is the whole reason the block-note test names `kind`.
--   * Five of the seven seeded notes become admin-only to write, because
--     `20260806031106:101-107` backfilled `schedule_block_id` onto them from their own detail
--     text. The two it could not match ("Serene Chu leaves at 2:30", "Hubert · Court 2") stay
--     member-writable, as does the LATC needs_action row — its detail leads with the time rather
--     than the title, so the backfill's `starts_with` test never matched it and its
--     `schedule_block_id` is still NULL.
--   * Nothing is pinned anywhere, in any camp, until an admin pins it. See section 1.
--   * `schedule_block_coaches` is empty. The seed writes no staffing, and inventing one would
--     put names against blocks nobody assigned.
--
-- IF THE CLIENT 404s ON `schedule_block_coaches` OR CANNOT SEE `inbox_items.pinned` AFTER THIS
-- APPLIES, it is PostgREST's schema cache, not this migration: it caches the schema it
-- introspected at start-up and a new relation or column is invisible until it reloads. The
-- manual nudge is
--
--     notify pgrst, 'reload schema';
--
-- run as any role that may connect. Supabase's own event trigger normally does this within a
-- second or two of the DDL committing; the notify is what to reach for when it has not.
