-- A kid gets a note, and two tables get the keys they were documented to have
--
-- Applied through the Supabase MCP against an emptied database on 2026-08-10, and written down
-- here so the repo and the project do not drift. Nothing in it has to reckon with existing rows.
--
-- ── Why this is not the drop-and-rebuild that was planned ────────────────────────────────────
--
-- The plan was to recreate all 21 tables and every policy from one consolidated migration, on the
-- grounds that twenty accumulated files are hard to read. The evidence argued the other way:
-- `get_advisors(security)` returns exactly two findings and neither is a defect.
-- `join_camp_by_code` is SECURITY DEFINER *because* joining by code has to read a camp you are
-- not yet a member of, and leaked-password protection is moot in a project whose only routes in
-- are an emailed code and Sign in with Apple. Thirty-nine policies across twenty-one tables were
-- all in force.
--
-- Recreating a schema with zero security defects to tidy its history is trading a real risk for a
-- cosmetic gain. The consolidation is still worth doing one day; it is not worth doing blind, and
-- it is certainly not worth doing in the same change as a data wipe.

-- ── A kid gets a note ────────────────────────────────────────────────────────────────────────
--
-- The design's kid page has a Notes card written straight to `kid.notes` — "Lefty · strong serve
-- · pick up at 3" — and `Player` had nowhere to put it.
--
-- On `players` rather than in the existing `feedback` table, which was the other candidate.
-- `feedback` is a log: many rows per kid, each with an author, a category and a resolved flag.
-- This is one line that replaces itself, belongs to the child rather than to whoever typed it,
-- and is read on every render of the roster — a join per row to fetch the latest of a log would
-- be the wrong shape for a field whose whole job is to be glanceable.
alter table public.players
  add column notes text not null default '';

-- Bounded, because it is drawn on one line in a card and a paste of somebody's life story would
-- silently break the layout rather than being refused. 280 is generous for "lefty, strong serve,
-- pick up at 3" and short enough to stay one field rather than becoming a document.
alter table public.players
  add constraint players_notes_length check (char_length(notes) <= 280);

comment on column public.players.notes is
  'One glanceable line about this kid, shown on their page. Not a log — see public.feedback.';

-- ── A pair table gets the key it was documented to have ──────────────────────────────────────
--
-- `schedule_block_coaches`'s own table comment says "The row is the pair, hence the composite
-- key", and there was no key: the linter reported the table as having no primary key at all.
-- Nothing stopped the same coach being added to the same block twice; the writer avoids it by
-- clearing and re-inserting rather than by anything the database enforces.
alter table public.schedule_block_coaches
  add constraint schedule_block_coaches_pkey primary key (block_id, coach_id);

-- ── Four foreign keys get covering indexes ───────────────────────────────────────────────────
--
-- Every FK on `tournament_matches` was unindexed. It is the one table in the schema that points
-- at another four times — two entrants and two feeder matches — so a bracket redraw is four
-- sequential scans per match, and deleting an entrant scans the whole table four times over to
-- find the rows referencing it. Cheap to fix while the table is empty.
create index tournament_matches_a_entrant_idx on public.tournament_matches (a_entrant_id);
create index tournament_matches_b_entrant_idx on public.tournament_matches (b_entrant_id);
create index tournament_matches_a_from_match_idx on public.tournament_matches (a_from_match);
create index tournament_matches_b_from_match_idx on public.tournament_matches (b_from_match);
