-- A venue knows its own shape
--
-- Three facts the venue editor collects and had nowhere to put.
--
-- Until now a venue's whole shape was `court_count` plus four min/max numbers, and everything
-- else the person shaping a camp decided — how many groups to split the kids into, roughly how
-- big a group should be, which ages this venue takes — either collapsed into the court count or
-- lived in a form and was thrown away when the sheet closed.
--
-- ── court_count is NOT what these add up to ──────────────────────────────────────────────────
--
-- `sites.court_count` already exists and stays exactly what it was: how many courts are on the
-- ground. `group_count` is a different question — how many groups the kids are split into — and
-- the two are not the same number. A venue with six courts can run four groups because two
-- courts are being resurfaced, and a venue with three courts can run four groups if one court
-- takes two. The app has been conflating them: `Venue.groupCount` on the Swift side reads
-- `court_count` here, so asking for "one more group" silently claimed a court that may not
-- exist.
--
-- Adding the column rather than reinterpreting the old one keeps every seeded row meaning what
-- it meant when it was written. The backfill below says so: existing venues get
-- `group_count = court_count`, which is precisely the behaviour they have today.
--
-- ── target_per_group is nullable because "no target" is a real answer ────────────────────────
--
-- The design's own words: "Optional target — over flags amber, never blocks". So the column has
-- to distinguish "aim for twelve" from "I have not decided", and it must never be a constraint —
-- a group over its target is drawn in amber and saved anyway. NULL is the undecided state; a
-- zero would be a target of nobody, which is a different and useless claim.
--
-- ── age_band is text with a CHECK rather than an enum type ───────────────────────────────────
--
-- Matching `camps.sport` and `coaches.role`, which are both text-plus-CHECK. A Postgres enum
-- would be tighter but cannot have a value removed, and this list is a product decision that has
-- already changed once. The three values are the ones the venue sheet offers.
--
-- Note what this column does NOT do: it does not filter anything by itself. It records which
-- ages the venue takes so that importing a roster can leave the kids who do not fit unassigned
-- rather than dealing them onto a court where they do not belong. A kid whose age is unknown
-- does not satisfy a restricted band — see `AgeBand.admits(_:)` on the Swift side, which refuses
-- to guess and reports the count instead.

begin;

alter table public.sites
  add column if not exists group_count     integer,
  add column if not exists target_per_group integer,
  add column if not exists age_band        text not null default 'all';

-- Every venue that already exists runs exactly as many groups as it has courts. That is not a
-- guess: it is what `Camp.syncGroups(for:)` has been doing since the model was written.
update public.sites set group_count = court_count where group_count is null;

alter table public.sites
  alter column group_count set not null,
  alter column group_count set default 4;

alter table public.sites
  drop constraint if exists sites_group_count_range,
  drop constraint if exists sites_target_per_group_range,
  drop constraint if exists sites_age_band_known;

alter table public.sites
  -- 1…40, which is deliberately *not* the venue sheet's stepper range.
  --
  -- The sheet caps groups at 12, and the first draft of this constraint copied that number. It
  -- was rejected by the table: a live venue ("Sycamore") already runs 13 groups, and three more
  -- run 9 or 10. A CHECK that refuses rows the database is already holding is not a stricter
  -- rule, it is a migration that cannot be applied — and had it been applied to an empty table
  -- and met that row later, it would have been a write failure in front of somebody adding a
  -- court.
  --
  -- So the two limits are separate on purpose, and they answer different questions. The stepper
  -- says how many groups you can *set* from this sheet, which is an ergonomic judgement about a
  -- thumb and a control. The constraint says which values are *coherent*, which is a fact about
  -- the data. 40 is the ceiling the same sheet already uses for courts, so a venue can be typed
  -- up to the number of courts it could plausibly have. Nothing here stops the sheet raising its
  -- own cap later; that would need no migration at all.
  --
  -- A venue with no groups holds no kids and is indistinguishable from one that does not exist,
  -- so zero stays out.
  add constraint sites_group_count_range
    check (group_count between 1 and 40),
  -- NULL is allowed and means undecided. When it is set it has to be a real head-count; the
  -- upper bound is the stepper's.
  add constraint sites_target_per_group_range
    check (target_per_group is null or target_per_group between 1 and 40),
  add constraint sites_age_band_known
    check (age_band in ('all', 'under_twelve', 'twelve_up'));

comment on column public.sites.group_count is
  'How many groups the venue splits its kids into. Distinct from court_count, which is how many '
  'courts exist on the ground — a venue can run fewer groups than it has courts, or more.';

comment on column public.sites.target_per_group is
  'Roughly how many kids a group should hold. NULL means no target was set. Never enforced: a '
  'group over target is flagged amber and saved anyway.';

comment on column public.sites.age_band is
  'Which ages this venue takes. Used when dealing an imported roster — kids who do not fit are '
  'left unassigned and counted, never silently dropped. A kid with no recorded age does not '
  'satisfy a restricted band.';

commit;
