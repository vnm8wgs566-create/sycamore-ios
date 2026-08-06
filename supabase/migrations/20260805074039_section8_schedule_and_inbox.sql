-- Section 8 of `Sycamore 3a System.dc.html` — "Final — the app in order" — introduces two
-- screens with nothing behind them:
--
--   8k  Schedule   one card per block, day-chipped Mon–Fri
--   8r  Inbox      "Needs you" items with an action, then a reverse-chronological feed
--
-- Every other screen in section 8 is already served: `today_courts` is the Overview card and
-- `roster_today` is the Groups row, both close enough to the design that they were plainly
-- built toward it. These two tables close the gap.
--
-- Conventions here follow the existing schema rather than improving on it in passing: uuid
-- primary keys defaulting to `gen_random_uuid()`, `timestamptz` audit columns, and `text`
-- rather than enum types for the small closed sets (`attendance.session`, `feedback.category`
-- and `assessments.kind` all do this). The `text` columns do get CHECK constraints, which the
-- existing ones lack — that is free at write time and it is the only thing keeping a typo out
-- of a column the UI switches on.

-- ---------------------------------------------------------------------------------------
-- 8k — Schedule
-- ---------------------------------------------------------------------------------------

create table if not exists public.schedule_blocks (
  id          uuid primary key default gen_random_uuid(),
  site_id     uuid not null references public.sites (id) on delete cascade,
  day         date not null,
  starts_at   time not null,
  -- Nullable: the design's 8:30 "Drop-off · done" has no stated end, and inventing one would
  -- put a time on screen that nobody entered.
  ends_at     time,
  title       text not null check (char_length(title) between 1 and 80),
  -- The grey second line: "Courts 1–3 · 22 players", "Shade lawn", "15 min". One free-text
  -- field rather than parsed columns because the design composes it differently per row.
  detail      text check (detail is null or char_length(detail) <= 160),
  status      text not null default 'planned'
              check (status in ('planned', 'done', 'needs_coach')),
  created_at  timestamptz not null default now(),

  constraint schedule_blocks_ends_after_starts
    check (ends_at is null or ends_at > starts_at)
);

-- One index, not two. The Schedule screen asks for "this site, this day, in time order", and
-- `site_id` leading also satisfies the foreign key — Postgres does not index FK columns for
-- you, and an unindexed one makes `on delete cascade` scan the whole table.
create index if not exists schedule_blocks_site_day_starts_idx
  on public.schedule_blocks (site_id, day, starts_at);

-- ---------------------------------------------------------------------------------------
-- 8r — Inbox
-- ---------------------------------------------------------------------------------------

create table if not exists public.inbox_items (
  id            uuid primary key default gen_random_uuid(),
  site_id       uuid not null references public.sites (id) on delete cascade,
  -- The design's three filter chips are All / Needs you / Notes, and the feed below them is a
  -- fourth thing again, so `kind` carries the distinction rather than two booleans that can
  -- disagree with each other.
  kind          text not null check (kind in ('needs_action', 'note', 'activity')),
  title         text not null check (char_length(title) between 1 and 120),
  detail        text check (detail is null or char_length(detail) <= 200),
  -- "Review", "Assign" — the button's label, null when the row is not actionable.
  action_label  text check (action_label is null or char_length(action_label) <= 24),

  -- Who did it ("Nass asked", "by Nass"). `set null` rather than cascade: a coach leaving the
  -- camp must not silently delete the history of what they did.
  actor_id      uuid references public.coaches (id) on delete set null,
  -- Who it is about ("Austin Zheng → Court 2"). Cascade, because an item about a deleted
  -- player has no subject left to be about.
  player_id     uuid references public.players (id) on delete cascade,
  group_id      uuid references public.groups (id) on delete set null,

  resolved      boolean not null default false,
  created_at    timestamptz not null default now(),

  -- Only actionable rows carry a button. The design's Notes and activity rows have none, and a
  -- stray label would render a button that does nothing.
  constraint inbox_items_action_label_only_when_actionable
    check (action_label is null or kind = 'needs_action')
);

-- The feed: this site, newest first.
create index if not exists inbox_items_site_created_idx
  on public.inbox_items (site_id, created_at desc);

-- The "Needs you · 2" count and its section, which is the first thing the screen draws and the
-- only query on this table that runs on every open. Partial, because the rows it excludes are
-- the overwhelming majority once a camp has been running a while.
create index if not exists inbox_items_needs_action_idx
  on public.inbox_items (site_id, created_at desc)
  where kind = 'needs_action' and not resolved;

create index if not exists inbox_items_actor_id_idx  on public.inbox_items (actor_id);
create index if not exists inbox_items_player_id_idx on public.inbox_items (player_id);
create index if not exists inbox_items_group_id_idx  on public.inbox_items (group_id);

-- ---------------------------------------------------------------------------------------
-- Row Level Security
-- ---------------------------------------------------------------------------------------
--
-- Matching the nine existing tables, which each carry one policy named `mvp_all`:
--
--     for all to public using (true)
--
-- That is RLS switched on and then opened all the way back up — with the anon key, anyone can
-- read and write every row. It is a placeholder, and these two tables adopt it deliberately so
-- the whole schema stays consistent and tightens in one pass rather than eleven.
--
-- When that pass happens, both tables are already shaped for it: they carry `site_id`, so the
-- policy becomes a site-membership check against `coaches.auth_uid`, and `site_id` already
-- leads an index on each table so the check is a lookup rather than a scan. Write it as
-- `(select auth.uid())` — wrapped in a sub-select it is evaluated once instead of per row.

alter table public.schedule_blocks enable row level security;
alter table public.inbox_items     enable row level security;

drop policy if exists mvp_all on public.schedule_blocks;
create policy mvp_all on public.schedule_blocks for all using (true);

drop policy if exists mvp_all on public.inbox_items;
create policy mvp_all on public.inbox_items for all using (true);
