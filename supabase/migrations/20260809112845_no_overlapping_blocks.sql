-- ---------------------------------------------------------------------------------------------
-- Two blocks at one venue may not claim the same minute.
-- ---------------------------------------------------------------------------------------------
--
-- `schedule_blocks` has had one time constraint since it was created:
--
--     constraint schedule_blocks_ends_after_starts
--       check (ends_at is null or ends_at > starts_at)          -- 20260805074039:38-39
--
-- which is a question about one row and says nothing whatever about the next one. A morning of
-- 9:00–11:00 skills and 10:00–10:30 water break satisfies it twice over and is still a timetable
-- that cannot happen.
--
-- Until now the only thing anywhere that refused it was `ScheduleResizePlan.init` in Swift, which
-- clamps a dragged bottom edge at the next block's start. That is one gesture on one screen. The
-- block editor's two time menus went straight past it — `BlockRules` checked `endsAfterStart` and
-- nothing else — and so does anything holding a service key and a `curl`. A rule that exists only
-- inside a drag is not a rule; it is a place where one path happens to behave.
--
-- ── WHY AN EXCLUDE AND NOT A CHECK OR A TRIGGER ───────────────────────────────────────────────
--
-- A CHECK cannot see another row, so the only way to write this as one is a subquery inside a
-- function, which Postgres does not enforce on the *other* row's write and which is documented as
-- unsafe for exactly this. A `before insert or update` trigger can see other rows but races: two
-- transactions each read a day with no conflict and each then insert into it, and both commit.
--
-- An EXCLUDE constraint is the one construction that is neither. It is an index, so it takes the
-- same locks a unique constraint does and two concurrent writes to the same minute serialise the
-- way two concurrent writes to the same unique key do. It is also the only one of the three that
-- is enforced against `update` as well as `insert` without being written twice.
--
-- ── btree_gist ────────────────────────────────────────────────────────────────────────────────
--
-- `site_id with =` needs a GiST operator class for `uuid`, which core Postgres does not ship —
-- GiST is built for the containment operators, and equality on a scalar is btree's job. `btree_gist`
-- is the extension that teaches GiST the btree operators, and it is what makes "same venue AND
-- overlapping range" expressible as one index rather than as two.
--
-- Checked before it was relied on: `pg_available_extensions` on this project offers `btree_gist`
-- 1.7 and had it installed nowhere. Into `extensions` rather than `public`, which is where this
-- project's other three already sit — `pgcrypto`, `uuid-ossp` and `pg_stat_statements` — and where
-- Supabase puts them by default. That placement is safe for the constraint below because the
-- *default* operator class for a type is resolved from `pg_opclass` by access method and input
-- type, not through `search_path`; `gist_uuid_ops` is found wherever the extension was installed.
--
-- ── WHY tsrange(day + starts_at, …) AND NOT A RANGE OF `time` ─────────────────────────────────
--
-- The obvious spelling is `(site_id with =, day with =, <a range of starts_at..ends_at> with &&)`,
-- and it cannot be written: Postgres ships no range type over `time`, so it would need a
-- `create type … as range (subtype = time)` first — a new type in the schema, for one constraint,
-- carrying its own constructors forever.
--
-- `day + starts_at` avoids all of it. `date + time` is `datetime_pl`, which returns `timestamp`
-- and is IMMUTABLE (checked in `pg_proc`, and an index expression may be nothing else), so the
-- built-in `tsrange` applies directly. Folding the day into the range also makes `day with =`
-- redundant rather than merely convenient: two blocks on different days are two ranges 24 hours
-- apart and cannot overlap, so stating the day again would only widen the index entry.
--
-- `tsrange(a, b)` is `[)` by default, and half-open is exactly the rule the camp wants: a block
-- that ends at 10:30 and one that starts at 10:30 abut, which is an ordinary morning. A block that
-- ends at 10:31 is two blocks claiming 10:30.
--
-- ── WHY IT IS PARTIAL ─────────────────────────────────────────────────────────────────────────
--
-- `where (ends_at is not null)`, because `ends_at` is nullable *by design* — 20260805074039:27-28
-- gives the reason ("the design's 8:30 `Drop-off · done` has no stated end, and inventing one
-- would put a time on screen that nobody entered"). `tsrange(x, null)` is a range unbounded above,
-- so an unfiltered constraint would read every open-ended block as running to the end of time and
-- refuse everything after it on that day. That is not a stricter rule, it is a different and wrong
-- one: every block `DayShape` writes is open-ended (`SupabaseRepository.applyDayShape` sends no
-- `ends_at` at all), so a full index would refuse the second block of every day built from a shape.
--
-- The cost is honest and worth naming: a block with no end constrains nothing and can be written
-- underneath anything. Swift is one step stricter here — see `BlockRules.latestEnd(for:in:)`,
-- which walls a drag at an open-ended neighbour anyway — and stricter on the client is free,
-- because a wall tighter than the column never produces a write the column then refuses.
--
-- ── IT IS NOT AN ORACLE ───────────────────────────────────────────────────────────────────────
--
-- 20260808211500:257-258 records that a unique violation is an information leak — "create a camp,
-- try venue names, and the errors tell you which ones exist somewhere else in the project". An
-- exclusion violation is the same kind of signal and is worth checking rather than assuming.
-- It is safe here because the constraint is keyed on `site_id`: a write can only ever conflict
-- with a row at the same venue, and RLS already requires membership of that venue's camp before
-- the write is attempted at all. There is no row you can collide with that you could not already
-- read.

create extension if not exists btree_gist with schema extensions;

-- ---------------------------------------------------------------------------------------------
-- The rows that are already wrong.
-- ---------------------------------------------------------------------------------------------
--
-- An EXCLUDE cannot be added `not valid` — Postgres offers that escape for CHECK and FOREIGN KEY
-- only — so the table has to be clean before the constraint exists, and any row that is not is an
-- error on somebody's deploy rather than a problem for later.
--
-- This project's own database held two blocks the day this was written, neither overlapping, so
-- the two passes below are expected to change nothing here. They are not written for this
-- database. Every camp that has ever used the app was free to write overlapping blocks through the
-- editor, and a repair that is not in the same migration as the constraint is a coin flip on
-- somebody else's deploy.
--
-- NOTHING IS DELETED. A block is somebody's morning; it has notes, coaches and courts hanging off
-- it, and dropping one to satisfy an index would be the migration destroying the data it was
-- written to protect. Both passes only ever *shorten* a claim.
--
-- PASS 1 — clamp each end at the start of the next block *that has an end of its own*.
--
--   After it, no two rows with different starts can both be constrained and overlap. A row
--   starting at s1 has its end clamped to the least such start strictly greater than s1; if
--   another constrained row starts at s2 > s1, then s2 is in that set, so the clamp is at most s2
--   and the first row stops at or before the second begins. It never crosses `ends_after_starts`
--   either — the ceiling is strictly greater than `starts_at` by construction.
--
--   `and n.ends_at is not null` is doing real work in that sentence and is worth defending, because
--   the app's own wall does not have it. `BlockRules.latestEnd(for:in:)` stops a drag at an
--   open-ended neighbour too, deliberately, and a first draft of this pass borrowed that rule
--   whole — which shortened an 08:00–12:00 block to 08:30 because a `Drop-off` with no end time
--   started there. Stricter is the right answer for a wall and the wrong one for a repair: no
--   constraint objects to that block, so shortening it is a migration destroying somebody's
--   morning to satisfy a rule that was not asking. The two rules differ on purpose, and this is
--   the narrower one.
--
-- PASS 2 — what pass 1 provably cannot reach: rows sharing a start, which have no strictly-greater
-- neighbour between them to be clamped at. `BlockRules.latestEnd(for:in:)` names the same corner
-- on the Swift side ("two blocks sharing a start neither follow nor clamp each other"). Those rows
-- keep everything except the claim that cannot be honoured: all but one lose `ends_at` and become
-- open-ended, which is a state the schema already blesses and the app already draws. The survivor
-- is the shortest, by id on a tie — a tie-break for determinism, not a judgement about which block
-- somebody meant.

do $$
declare
  clamped integer;
  opened  integer;
begin
  -- One statement, so the correlated subquery reads the day as it was before any of it moved.
  -- Two passes of `update … where ends_at > (select …)` would clamp against ends this same
  -- statement had already pulled in.
  with wall as (
    select b.id,
           (select min(n.starts_at)
              from public.schedule_blocks n
             where n.site_id = b.site_id
               and n.day = b.day
               and n.starts_at > b.starts_at
               -- Only blocks the constraint can see. A neighbour with no end conflicts with
               -- nothing, so clamping at it would shorten a block nobody objected to.
               and n.ends_at is not null) as ceiling
      from public.schedule_blocks b
     where b.ends_at is not null
  )
  update public.schedule_blocks b
     set ends_at = wall.ceiling
    from wall
   where b.id = wall.id
     and wall.ceiling is not null
     and b.ends_at > wall.ceiling;
  get diagnostics clamped = row_count;

  with ranked as (
    select id,
           row_number() over (
             partition by site_id, day, starts_at
             order by ends_at, id
           ) as seat
      from public.schedule_blocks
     -- Open-ended rows are exempt from the constraint, so they are not competing for the seat
     -- and must not push a row that *is* constrained out of it.
     where ends_at is not null
  )
  update public.schedule_blocks b
     set ends_at = null
    from ranked
   where b.id = ranked.id
     and ranked.seat > 1;
  get diagnostics opened = row_count;

  if clamped > 0 or opened > 0 then
    raise notice
      'schedule_blocks: % row(s) shortened to the next block, % row(s) left open-ended',
      clamped, opened;
  end if;
end $$;

-- ---------------------------------------------------------------------------------------------
-- The constraint.
-- ---------------------------------------------------------------------------------------------
--
-- `duplicate_table` as well as `duplicate_object`, unlike the CHECKs in 20260809030000: an EXCLUDE
-- brings an index along with it, so a half-applied run can leave either name taken.

do $$ begin
  alter table public.schedule_blocks
    add constraint schedule_blocks_no_overlap
    exclude using gist (
      site_id with =,
      tsrange(day + starts_at, day + ends_at) with &&
    ) where (ends_at is not null);
exception when duplicate_object or duplicate_table then null; end $$;

comment on constraint schedule_blocks_no_overlap on public.schedule_blocks is
$$Two blocks at one venue on one day may not claim the same minute. Half-open, so a block ending
at 10:30 and one starting at 10:30 abut rather than overlap. Blocks with no `ends_at` are exempt —
the column is nullable by design and every block a day shape writes has no end. Mirrored in Swift
as `BlockRules.overlap(with:in:)`.$$;