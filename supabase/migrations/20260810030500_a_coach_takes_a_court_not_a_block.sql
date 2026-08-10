-- ---------------------------------------------------------------------------------------------
-- A coach is put on a court of a block, not merely on the block.
-- ---------------------------------------------------------------------------------------------
--
-- ── WHY ───────────────────────────────────────────────────────────────────────────────────────
--
-- `schedule_block_coaches` (20260808201645:277-282) records that these coaches are running this
-- block. That was the whole of the question when it was written, and the header says so: "Who is
-- running a block. That is a set of coaches, so it is a table." A block was a thing at a venue,
-- and the venue was as fine-grained as the answer needed to be.
--
-- It is not any more. `schedule_block_courts` (20260809030000:68-73) gave a block its courts, and
-- designs 4d and 5d ask the next question straight away — 5d draws one row per court with a coach
-- on it, and 4d opens from that row under the title "Who takes Court 2?". A flat set of coaches
-- cannot answer it. "Nass and Alina are running Match play on Courts 1–3" is what the table can
-- say; "Nass has Court 1, Alina has Court 2, Court 3 is short" is what the screen draws, and the
-- difference is not detail — it is the entire content of both designs.
--
-- The Swift half has already landed as `ScheduleBlock.staffing: [BlockCourtStaffing]`
-- (`Sycamore/Models/SectionEight.swift:114-144, 202`), declared beside `coachIDs` rather than
-- replacing it, and that shape is the one this migration mirrors: **a column on the existing row,
-- not a second table**. A `schedule_block_court_coaches` beside `schedule_block_coaches` would be
-- two tables holding one fact — who is on this block — split on whether the fact happens to name a
-- court, with two policies, two covers on save, and every read having to merge them before a card
-- could be drawn. The row already carries a block and a coach. It gains the court.
--
-- ── NULLABLE, AND THEREFORE NO BACKFILL ───────────────────────────────────────────────────────
--
-- NULL is not missing data here. It means *on the block as a whole*, which is exactly and only
-- what every row written before this migration meant, and what a `.regular` block — one that names
-- no courts at all (`ScheduleBlockKind`, `SectionEight.swift:518`) — can ever mean. So existing
-- rows are already correct under the new reading and there is nothing to fill in. On this project
-- that is one row; on a deploy with a season behind it, it is every row, and the answer is the
-- same for all of them.
--
-- A `not null` column with a sentinel court was never on the table, and a backfill guessing a court
-- from `schedule_block_courts` would be worse than either. A block on Courts 1–3 with two coaches
-- on it does not say which of the three each is on — the app has never asked — so a backfill could
-- only deal names across courts and write down an assignment nobody made. `20260808201645:53-63`
-- refuses a backfill on this reasoning for `inbox_items.pinned`, and 20260806031106:19-22 for
-- `players.last_name`: a column that starts honest beats a column that starts full.
--
-- The two readings coexist on one block by design, and that is the second reason the column is
-- nullable rather than the table being split. A floater across a whole session *plus* a name per
-- court is an ordinary morning, and it is one block with rows of both kinds on it.
--
-- ── THE PRIMARY KEY CANNOT SIMPLY BE WIDENED, AND THIS IS THE HEART OF THE FILE ───────────────
--
-- The obvious move is `primary key (block_id, coach_id, group_id)`. It is not available: a PRIMARY
-- KEY implies NOT NULL on every column in it. Widening the key would therefore force `group_id`
-- NOT NULL — which contradicts the paragraph above outright, would refuse the row already in this
-- table, and would make "on the block as a whole" unsayable at the moment it is the only thing
-- most rows say. The constraint has to be a UNIQUE, and the key has to be dropped rather than
-- extended.
--
-- Plain UNIQUE is not enough either, and this is the trap worth naming. Under the SQL default,
-- NULLs are distinct — so `unique (block_id, coach_id, group_id)` would permit `(b, c, NULL)`
-- twice over, and the one guarantee the old primary key bought would be gone. That guarantee is
-- load-bearing and 20260808201645:266-268 says why: the client rewrites a block's staffing as
-- delete-then-insert, and the key is what makes that "incapable of leaving duplicates behind,
-- rather than merely unlikely to". `NULLS NOT DISTINCT` (Postgres 15+; this project is 17.6,
-- checked rather than assumed) restores it exactly — two block-wide rows for one coach collide
-- again, while the same coach on two different courts does not, which is the whole point of the
-- change.
--
-- What is deliberately still permitted, both before and after: two *different* coaches on one
-- court of one block. That is the ten-minute handover `BlockRules.overlaps` argues at length the
-- app must be able to write down, and `BlockCourtStaffing.coachIDs` is an array rather than a set
-- for the same reason.
--
-- ── DROPPING THE KEY TAKES AN INDEX WITH IT, AND ONE HAS TO REPLACE IT ────────────────────────
--
-- `schedule_block_coaches_pkey` is not only a constraint; it is the btree on `(block_id, coach_id)`
-- that 20260808201645:289-296 identifies as serving "every `block_id = $1` lookup the Schedule
-- screen makes and the cascade from `schedule_blocks`". Drop it with nothing in its place and
-- every schedule read and every block deletion falls back to a sequential scan under a lock.
--
-- The unique index below is that replacement, and no separate index is needed: it leads with
-- `block_id`, so it drives `block_id = $1` and the `schedule_blocks` cascade exactly as the old key
-- did, and it happens to carry `group_id` as a third column. One index out, one index in.
--
-- Two partial unique indexes — one `where group_id is null` on `(block_id, coach_id)`, one
-- `where group_id is not null` on all three — were considered and rejected. They state the same
-- rule on any Postgres back to 9.x, but the planner may only use a partial index when it can prove
-- the predicate, and the referential-integrity check behind the cascade asks `where block_id = $1`
-- with nothing said about `group_id`. Neither index could serve it, so a third plain index would be
-- needed beside them: three indexes on a table of a few rows per block, to avoid one clause.
--
-- ── TWO THINGS CHECKED BEFORE THE KEY WAS DROPPED, NOT ASSUMED ────────────────────────────────
--
-- `block_id` and `coach_id` stay NOT NULL. They were declared `not null` in the CREATE TABLE
-- (20260808201645:278-279) independently of the key, so dropping the key takes the uniqueness and
-- the index and leaves the nullability alone. Worth stating because the reverse — columns that
-- were only NOT NULL by virtue of being in a primary key — is the ordinary case, and this is not
-- it.
--
-- This table is not published for realtime. `REPLICA IDENTITY DEFAULT` uses the primary key, so a
-- table in a publication that carries UPDATE or DELETE would start refusing both with
-- `55000 cannot update table … because it does not have a replica identity` the moment its key
-- went — which for this table would be every save of a block's staffing, since the client covers
-- rather than diffs. `supabase_realtime` on this project publishes `players`, `ratings`,
-- `attendance` and `court_assignments`, `puballtables` is false, and `schedule_block_coaches` is
-- in neither publication. If it is ever added to one it will need `alter table … replica identity
-- full`, and not `using index schedule_block_coaches_key`: that form requires every column of the
-- index to be NOT NULL, and `group_id` is the one column here that deliberately is not.
--
-- ── ORDER OF OPERATIONS ───────────────────────────────────────────────────────────────────────
--
-- Column, then the new unique constraint, then drop the old key. Never the reverse: between the
-- drop and the create there would be a window with no uniqueness on the table at all, and this
-- file may be applied against a database an app is talking to.

alter table public.schedule_block_coaches
  add column if not exists group_id uuid;

alter table public.schedule_block_coaches
  drop constraint if exists schedule_block_coaches_group_id_fkey;
alter table public.schedule_block_coaches
  add constraint schedule_block_coaches_group_id_fkey
  foreign key (group_id) references public.groups (id) on delete cascade;

-- `on delete cascade`, matching both foreign keys already on this table and the `group_id` on its
-- sibling `schedule_block_courts` (20260809030000:70). The reasoning is 20260808201645:270-275's
-- and holds unchanged: an assignment is not history. A row naming a court that has been deleted in
-- Setup is not a record worth keeping — it is a coach the block editor would draw against nothing.
-- Note it cascades the *row*, not the column: a deleted court removes that coach's per-court
-- assignment entirely rather than demoting it to a block-wide one, which would silently widen an
-- assignment somebody made narrowly.

do $$ begin
  alter table public.schedule_block_coaches
    add constraint schedule_block_coaches_key
    unique nulls not distinct (block_id, coach_id, group_id);
exception when duplicate_object then null; end $$;

alter table public.schedule_block_coaches
  drop constraint if exists schedule_block_coaches_pkey;

-- ── AND IT TAKES THE REPLICA IDENTITY WITH IT, WHICH IS A TRAP LAID FOR LATER ────────────────
--
-- `relreplident` on this table is `d` — DEFAULT, which means "use the primary key". Dropping the
-- key therefore leaves the table with no replica identity at all. Nothing breaks today: it is in
-- no publication (checked, not assumed), so nothing is decoding its WAL and the setting is inert.
--
-- It breaks the first time somebody adds this table to `supabase_realtime` to watch staffing
-- change live — which is a plausible thing to want on precisely this table. At that moment every
-- UPDATE and DELETE starts failing with "cannot update table … because it does not have a replica
-- identity and publishes updates", and the cause will be three migrations behind the symptom.
--
-- The usual repair — `replica identity using index` — is not available here: an index backing a
-- replica identity must be over NOT NULL columns, and `group_id` is nullable by design. So FULL,
-- which logs the whole old row. The cost of FULL is proportional to row width and row count, and
-- this table is four narrow columns holding one row per coach per court per block. That is the
-- cheapest table in the schema to pay it on.
alter table public.schedule_block_coaches replica identity full;

comment on constraint schedule_block_coaches_key on public.schedule_block_coaches is
  'Was the primary key (block_id, coach_id). A PK cannot hold a nullable column, and group_id is '
  'nullable because NULL means "on the block as a whole". NULLS NOT DISTINCT keeps two block-wide '
  'rows for one coach colliding, which is what the delete-then-insert cover relies on.';

comment on column public.schedule_block_coaches.group_id is
  'The court of the block this coach is running. NULL means the block as a whole, which is what '
  'every row written before this column existed means and the only thing a regular block can mean.';

-- ── THE NEW FOREIGN KEY IS INDEXED, WHICH THIS SCHEMA HAS NOW STATED FOUR TIMES ───────────────
--
-- Postgres does not index a foreign key for you, and an unindexed one makes `on delete cascade`
-- scan the whole table under a lock. `20260805074039:43-44` says it, `20260805141707:132-135` says
-- it over ten of them at once, `20260808201645:289-296` says it for this table's own `coach_id`,
-- and `20260809030000:65-66` says it for `schedule_block_courts.group_id` — which is the identical
-- column on the identical shape of table, and therefore the exemplar this line copies rather than
-- re-argues.
--
-- The cascade this protects is the one that fires when a *court* is deleted: `dropCourts`
-- (`SupabaseRepository+Graph.swift:242-264`) runs whenever a venue's court count is trimmed in
-- Setup, and a camp deletion fans out through `sites` to `groups` to here. The new unique index
-- leads with `block_id` and cannot drive `group_id = $1`, so this is not redundant with it.
--
-- Not partial, unlike `inbox_items_schedule_block_idx` (`20260806031106:85-91`). That one is
-- `where schedule_block_id is not null` because the column is null for most rows there and `= $1`
-- proves `is not null`. The same would be true here — most rows are block-wide — but the whole
-- table is a handful of rows per block, and a plain index is what the sibling column uses. Two
-- identical columns on two identical tables indexed two different ways is how the next person
-- reading them concludes that one of the two was a mistake.

create index if not exists schedule_block_coaches_group_idx
  on public.schedule_block_coaches (group_id);

-- ── THE POLICY GROWS A THIRD TEST, AND WITHOUT IT THIS COLUMN IS AN ISOLATION HOLE ────────────
--
-- `schedule_block_coaches_member` (20260808201645:332-342) tests both ends of the row with `and`,
-- and that file explains at length why `and` rather than `or`: with `or`, a member of camp A names
-- one of their own blocks and any coach uuid they can find, and a uuid from camp B satisfies the
-- policy through the block half alone.
--
-- `group_id` is a third uuid the caller now supplies, and it arrived after that argument was
-- written. Untested, it is the same hole in a new column: a member attaches a court from a camp
-- they are not in to a block they can reach, and the block editor draws a stranger's court on
-- somebody's Tuesday. `schedule_block_courts_member` (20260809030000:83-93) is the exact precedent
-- and closes it with `group_id in (select private.group_ids_for_caller())`; this is that clause
-- with one disjunct in front, because here the column may legitimately be NULL.
--
-- `group_id is null or …`, in that order, and the order is not cosmetic: `NULL in (select …)`
-- evaluates to NULL, not false, and a policy clause that answers NULL is a denial. Without the
-- null test every block-wide row — which is to say every row that exists today — would become
-- unwritable and unreadable the moment this policy replaced the old one. That is the failure
-- `20260808201645:181-184` warns about, arriving on the one column that is null nearly everywhere.
--
-- **No existing row is refused by this.** The row in this table has `group_id` NULL, so the first
-- disjunct is true for it and the policy is exactly as permissive as it was. The change is
-- additive in the only sense that matters for a policy: it narrows nothing that is already there
-- and refuses one thing that has never been possible to write.
--
-- `for all` and one policy per command, unchanged — `20260806031119:127-128` records that this
-- schema keeps one policy per command per table so the `multiple_permissive_policies` advisor stays
-- quiet, and a second policy beside this one would land on all four commands at once.
--
-- Member-writable, unchanged, and the coupling 20260808201645:328-331 states still holds: if block
-- editing is ever made admin-only, this policy and `schedule_blocks_member` must change together.

drop policy if exists schedule_block_coaches_member on public.schedule_block_coaches;
create policy schedule_block_coaches_member on public.schedule_block_coaches
  for all to authenticated
  using (
    block_id in (select private.schedule_block_ids_for_caller())
    and coach_id in (select private.coach_ids_for_caller())
    and (group_id is null or group_id in (select private.group_ids_for_caller()))
  )
  with check (
    block_id in (select private.schedule_block_ids_for_caller())
    and coach_id in (select private.coach_ids_for_caller())
    and (group_id is null or group_id in (select private.group_ids_for_caller()))
  );

-- ── WHAT IS DELIBERATELY NOT HERE ─────────────────────────────────────────────────────────────
--
-- **No CHECK that `group_id` is one of the block's own courts.** It is the constraint a reader
-- will look for, and SQL cannot state it: the block's courts live in `schedule_block_courts`, so
-- the test spans two tables and a CHECK indexes columns of one row. The alternatives are a
-- constraint trigger — which `20260809112845` argues races, and `20260810020558` cites that
-- argument approvingly on its way to removing a constraint for exactly this class of reason — or a
-- composite foreign key into `schedule_block_courts (block_id, group_id)`, which would be sound
-- but would forbid the ordinary intermediate state the editor passes through: 5b lets a court be
-- unticked while a coach is still shown against it, and the save that follows rewrites both
-- children. The Swift side holds the rule where the editor can show it
-- (`BlockEditorDraft`), which is the same division of labour `20260808201645:300-305` records for
-- `schedule_blocks`' own CHECKs.
--
-- **No grant.** `20260808201645:369` already granted select/insert/update/delete on this table to
-- `anon, authenticated`, and adding a column does not change a table-level privilege.
--
-- **`created_at` untouched.** It is still read as an `order` and never as a value
-- (`SupabaseDTOs.ScheduleBlockCoachRecord`), and it is now what keeps a court's two coaches in the
-- order they were written as well as a block's.
--
-- ── WHAT CHANGES THE MOMENT THIS APPLIES ──────────────────────────────────────────────────────
--
--   * Nothing on screen, until a block is saved with per-court staffing on it. Every row in the
--     table reads back as `ScheduleBlock.coachIDs` exactly as before, because every row has a NULL
--     court and the client sorts the two apart on precisely that
--     (`SupabaseRepository+SectionEight.scheduleBlocks(forVenue:day:campID:)`).
--   * The same coach may hold two courts of one block, which the old primary key refused with a
--     `23505`.
--   * A client that has not been updated keeps working. It selects named columns rather than `*`
--     from this table and writes rows without `group_id`, which the nullable column accepts — so
--     an old build staffs a block as a whole, which is the only thing it knows how to say.
--   * If the client 404s or reports `PGRST204` on `group_id` immediately afterwards, it is
--     PostgREST's schema cache rather than this file. `20260808201645:405-413` has the nudge:
--
--         notify pgrst, 'reload schema';
