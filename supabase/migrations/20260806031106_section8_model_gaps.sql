-- Three columns section 8 draws and the schema could not say.
--
-- Each was found by measuring a screen against its CSS, and each is additive and nullable, so
-- every seeded row keeps reading exactly as it did.
--
-- The fourth gap in the same pass — a roster row imported with no age landing as `0` on `8d`
-- ("Check the import") — needs no DDL at all. `players.age` is already `integer null` with a
-- `check (age between 4 and 19)`, and 41 of the 100 seeded players are already NULL. The gap was
-- only ever in Swift, where `Player.age` is a non-optional `Int` and `?? 0` invents a zero the
-- column never held. That half is fixed in `Models.swift`; nothing here needs to change for it.

-- ---------------------------------------------------------------------------
-- 1. players.last_name — the design writes "Serene Chu", not "Serene C"
-- ---------------------------------------------------------------------------
-- `8i`, `8j`, `8o` and `8d` all render a full surname; `last_initial` can only ever produce the
-- letter. The initial stays: it is what ~21 files read today, and a camp that has only ever
-- collected initials still has them.
--
-- NOT BACKFILLED, deliberately. "C" is not "Chu" — a surname cannot be recovered from its first
-- letter, and writing `last_name = last_initial` would turn a known gap into 100 rows that look
-- filled in. Every row stays NULL until an import or an edit supplies a real name, and
-- `Player.displayName` falls back to the initial meanwhile.

alter table public.players add column if not exists last_name text;

alter table public.players drop constraint if exists players_last_name_len;
alter table public.players add constraint players_last_name_len
  check (last_name is null or char_length(last_name) between 1 and 60);

comment on column public.players.last_name is
  'Full surname. NULL where only last_initial was ever collected — never derived from it.';

-- ---------------------------------------------------------------------------
-- 2. groups.activity — what this court is doing, when it is not the block's title
-- ---------------------------------------------------------------------------
-- `8i`/`8j` title each court card with its own activity: "Drills" on court 1, "Match play" on 2,
-- "Skills rotation" on 3, "Net down" on 4 — while the running block, in the header, is
-- "Skills rotation · until 10:30". Three of those four disagree with the block, so an activity
-- resolved from the schedule can only ever draw one card correctly.
--
-- Neither existing text column is free: `name` is "Group N", which `8o` prints as the group
-- heading, and `court_label` is "Court N", which the same card prints in its subtitle.
--
-- NULL is meaningful and is the default: this court is doing whatever the block says. Only a
-- court that has departed from the schedule needs a value, which is why there is no backfill —
-- writing today's block title onto all 12 courts would assert a departure nobody made.
--
-- 80 characters to match `schedule_blocks.title`; a court's activity is the same kind of noun.

alter table public.groups add column if not exists activity text;

alter table public.groups drop constraint if exists groups_activity_len;
alter table public.groups add constraint groups_activity_len
  check (activity is null or char_length(activity) between 1 and 80);

comment on column public.groups.activity is
  'This court''s own activity, overriding the running block''s title. NULL follows the schedule.';

-- The `today_courts` view is deliberately left alone. It is not `security_invoker`, so it reads
-- around every policy in `20260806013152_real_rls.sql`, and it currently holds no grant for
-- `anon` or `authenticated` — which is why `SupabaseRepository+SectionEight` assembles the same
-- card from `groups` directly. That path selects `groups.*`, so it picks `activity` up as it
-- stands. Adding a column to a view nobody may select would buy nothing, and granting select on
-- a definer's-rights view over every camp's players would undo the RLS pass.

-- ---------------------------------------------------------------------------
-- 3. inbox_items.schedule_block_id — whose notes these are
-- ---------------------------------------------------------------------------
-- `8k` puts a note footer on every block card: "1 note · shade tent is up" on Water & regroup,
-- "2 notes" on Match play, "1 note · two nut allergies" on Lunch. A note is an `inbox_items` row
-- of `kind = 'note'` tied only to a group, and a group spans every block of the day, so the card
-- can currently only guess. This is the edge that makes the count a fact.
--
-- `on delete cascade`: a note reading "Match play 10:45 · net still down" is about that block and
-- outlives nothing when it is deleted. The column is left nullable and unconstrained by `kind`
-- — plenty of inbox rows are about the camp rather than a block, and narrowing that to notes
-- would be a decision the design does not make.

alter table public.inbox_items add column if not exists schedule_block_id uuid;

alter table public.inbox_items drop constraint if exists inbox_items_schedule_block_id_fkey;
alter table public.inbox_items add constraint inbox_items_schedule_block_id_fkey
  foreign key (schedule_block_id) references public.schedule_blocks (id) on delete cascade;

-- Postgres indexes no foreign key on its own, and an unindexed one turns every block deletion
-- into a sequential scan holding a lock over the whole table. Partial because the column is null
-- for most rows and `= $1` proves `is not null`, so the planner may still use it for both the
-- cascade and `8k`'s per-block count.
create index if not exists inbox_items_schedule_block_idx
  on public.inbox_items (schedule_block_id)
  where schedule_block_id is not null;

comment on column public.inbox_items.schedule_block_id is
  'The block this row is about, for 8k''s note count. NULL for anything not tied to one.';

-- Backfill, from what the rows already say rather than from a guess: every seeded note names its
-- block as the first segment of `detail` — "Lunch · shade lawn · check labels", "Water & regroup
-- · 10:30". Matched on the same site and the block for the day the row was written, so two days
-- of identically-titled blocks cannot collide. `starts_with` rather than `like` so a title
-- containing `%` or `_` could never widen the match. Rows whose detail names no block keep NULL.
update public.inbox_items i
set schedule_block_id = b.id
from public.schedule_blocks b
where i.schedule_block_id is null
  and b.site_id = i.site_id
  and b.day = (i.created_at at time zone 'UTC')::date
  and starts_with(lower(i.detail), lower(b.title));
