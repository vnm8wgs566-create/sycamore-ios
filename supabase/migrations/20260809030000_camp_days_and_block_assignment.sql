-- ---------------------------------------------------------------------------------------------
-- Which days a camp runs, what kind of thing a block is, and which courts it runs on.
-- ---------------------------------------------------------------------------------------------
--
-- Three additions, all of them things the app had been carrying as prose or as a stub.
--
-- 1. `camps.camp_days` — a camp's operating days. The model believed every camp ran Monday to
--    Friday (`Weekday` had no weekend case at all, and `Weekday.today` returned Wednesday
--    unconditionally). A swim club that runs Saturday mornings could not say so.
--
-- 2. `schedule_blocks.kind` — whether a block is a plain event or one that names its courts and
--    coaches. Deliberately a new column rather than a fourth `status`: status is
--    `planned|done|needs_coach`, which answers where a block has got to, and a kind answers what
--    it is. Overloading them would make "a done warm-up" unsayable.
--
-- 3. `schedule_block_courts` — which courts a block runs on. Until now that lived inside
--    `schedule_blocks.detail`, one free-text line reading "Courts 1–3 · 22 players" that the
--    column comment itself describes as composed differently on every row. Nothing could read it
--    back, so nothing could act on it.
--
-- WHY A BITMASK FOR THE DAYS
--
-- Seven bits, one column, read on every schedule load. The alternatives were a `camp_days` join
-- table — seven rows to say what a number says, and a join on the hottest read in the app — or
-- seven booleans, which cannot be handed around as one value. Bit 0 is Monday, so the bit index
-- is `Weekday`'s raw value less one, and `CampDays.rawValue` is the wire format unchanged.
--
-- Default 31 = 0b0011111 = Monday through Friday. Every camp written before this column existed
-- is therefore read as Monday-to-Friday, which is what they all were. `> 0` rather than a plain
-- range check because a camp with no days is a camp nothing can be scheduled on; the editor
-- refuses the empty set too, and this is the backstop for anything that reaches the API directly.

alter table public.camps
  add column if not exists camp_days smallint not null default 31;

do $$ begin
  alter table public.camps add constraint camps_camp_days_check
    check (camp_days > 0 and camp_days <= 127);
exception when duplicate_object then null; end $$;

comment on column public.camps.camp_days is
$$Which days this camp opens, as a seven-bit mask: bit 0 Monday … bit 6 Sunday.
Mirrors `CampDays.rawValue` in Swift. Default 31 is Monday-to-Friday, which is what every camp
created before this column existed meant.$$;

-- ---------------------------------------------------------------------------------------------

alter table public.schedule_blocks
  add column if not exists kind text not null default 'regular';

do $$ begin
  alter table public.schedule_blocks add constraint schedule_blocks_kind_check
    check (kind in ('regular', 'assigned'));
exception when duplicate_object then null; end $$;

-- ---------------------------------------------------------------------------------------------
-- The courts a block runs on.
--
-- Modelled on `schedule_block_coaches` (20260808201645:277-298), and for the same reasons that
-- file argues: a composite primary key rather than a surrogate uuid, because the row *is* the
-- pair and there is nothing else to say about it; and both foreign keys cascade, because an
-- assignment is not history — when the block goes or the court goes, so does the fact that they
-- were once put together.
--
-- The index on `group_id` earns its place the same way that file's does: the composite PK indexes
-- `(block_id, group_id)`, which cannot drive the cascade that fires when a *court* is deleted.

create table if not exists public.schedule_block_courts (
  block_id   uuid not null references public.schedule_blocks (id) on delete cascade,
  group_id   uuid not null references public.groups (id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (block_id, group_id)
);

create index if not exists schedule_block_courts_group_idx
  on public.schedule_block_courts (group_id);

alter table public.schedule_block_courts enable row level security;

-- Both ends tested, with `and` rather than `or` — the shape `schedule_block_courts`' sibling
-- uses. An `or` would let a member of one camp attach any court uuid they could name to a block
-- they can reach, which is the isolation hole 20260808211500 was written to close.
drop policy if exists schedule_block_courts_member on public.schedule_block_courts;
create policy schedule_block_courts_member on public.schedule_block_courts
  for all to authenticated
  using (
    block_id in (select private.schedule_block_ids_for_caller())
    and group_id in (select private.group_ids_for_caller())
  )
  with check (
    block_id in (select private.schedule_block_ids_for_caller())
    and group_id in (select private.group_ids_for_caller())
  );

-- Redundant by design, and the redundancy is the point. `alter default privileges` is
-- per-grantor (20260805152045:47-48), so a table created by a different role than the one whose
-- defaults were set gets none of them. Stating the grant is what stops this table answering 42501
-- on its first read.
grant select, insert, update, delete on public.schedule_block_courts to authenticated;

comment on table public.schedule_block_courts is
$$Which courts a scheduled block runs on. Replaces the free text in `schedule_blocks.detail`,
which composed the same fact differently on every row and could not be read back.$$;
