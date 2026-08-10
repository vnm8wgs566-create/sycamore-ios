-- A tournament is a draw over a ladder
--
-- Five tables for the Tournament tab. They are five and not one because a tournament is not a
-- document — it points at kids, and kids get removed.
--
-- ── Why not one JSONB column ────────────────────────────────────────────────────────────────
--
-- The obvious cheap shape is `sites.tournaments jsonb`, which is exactly what the design
-- prototype does (it keeps the whole thing in localStorage). It was rejected for one reason:
-- removing a venue deletes its kids, and a blob of player ids has no way to hear about that. The
-- draw would keep rendering entrants whose names no longer resolve, and no constraint anywhere
-- would call it wrong. Every id below is a real foreign key with a real cascade, so a kid who
-- leaves the camp leaves the draw.
--
-- The one deliberate exception is `tournaments.group_ids`, and it is an exception because it is
-- *provenance* rather than a relationship — see the comment on that column.
--
-- ── The entrant is the unit, not the player ─────────────────────────────────────────────────
--
-- Singles, doubles and team look like three different shapes and are one: something enters, and
-- it is made of one or more kids. So `tournament_entrants` is the competitor and
-- `tournament_entrant_players` is its membership, for all three formats. A singles entrant has
-- one row there, a doubles pair has two, a team has as many as it drafted. Nothing branches on
-- format to find out who is playing.
--
-- That is also what lets the match table be format-blind: a match is two entrants, whatever an
-- entrant happens to be made of.

begin;

-- MARK: - The tournament

create table if not exists public.tournaments (
  id          uuid primary key default gen_random_uuid(),
  site_id     uuid not null references public.sites(id) on delete cascade,
  name        text not null,
  kind        text not null,
  mode        text not null,
  -- Which groups were asked for when this draw was seeded. NOT a foreign key and not a join
  -- table, because it is a record of a decision already carried out rather than a live
  -- relationship: the pool it selected is written down in `tournament_entrant_players`, and
  -- re-reading these ids never changes who is playing. A group deleted afterwards leaves an id
  -- here that resolves to nothing, which is the correct history — that group *was* included.
  group_ids   uuid[] not null default '{}',
  -- How many days the draw is meant to run over. Planning only; nothing schedules from it yet.
  days        smallint not null default 1,
  sort_index  smallint not null default 0,
  created_at  timestamptz not null default now(),

  constraint tournaments_kind_known check (kind in ('singles', 'doubles', 'team')),
  -- 'team' carries neither: a team draft has no fixtures, it has teams. The CHECK below lets a
  -- team row say so rather than forcing it to claim a mode it does not use.
  constraint tournaments_mode_known check (mode in ('round_robin', 'knockout', 'none')),
  constraint tournaments_team_has_no_mode
    check ((kind = 'team') = (mode = 'none')),
  constraint tournaments_days_range check (days between 1 and 14),
  constraint tournaments_name_len check (char_length(name) between 1 and 80)
);

create index if not exists tournaments_site_idx on public.tournaments (site_id, sort_index);

-- MARK: - Who is entered

create table if not exists public.tournament_entrants (
  id            uuid primary key default gen_random_uuid(),
  tournament_id uuid not null references public.tournaments(id) on delete cascade,
  -- Position in the seeding, 1-based and dense. The draw reads 1-vs-N off this, and round robin
  -- uses it only for a stable running order.
  seed          smallint not null,
  -- Team name. Null for singles and doubles, where the label is built from the members' names
  -- and storing it would be a second place for a kid's name to be wrong.
  name          text,
  -- Doubles only: this pair asked for each other rather than being matched by rank. Kept because
  -- the screen says so out loud, and because re-seeding has to honour it again.
  is_requested  boolean not null default false,

  constraint tournament_entrants_seed_positive check (seed >= 1),
  constraint tournament_entrants_name_len
    check (name is null or char_length(name) between 1 and 60),
  unique (tournament_id, seed)
);

create table if not exists public.tournament_entrant_players (
  entrant_id uuid not null references public.tournament_entrants(id) on delete cascade,
  player_id  uuid not null references public.players(id) on delete cascade,
  -- 0-based position within the entrant. For doubles this is which half of the pair; for a team
  -- it is draft order, which is the order the snake put them in and therefore worth keeping.
  slot       smallint not null,

  primary key (entrant_id, player_id),
  constraint tournament_entrant_players_slot_range check (slot >= 0),
  unique (entrant_id, slot)
);

create index if not exists tournament_entrant_players_player_idx
  on public.tournament_entrant_players (player_id);

-- Team tennis only: which coaches are running a team. A coach can take more than one team and a
-- team can have more than one coach, which is why this is a join rather than a column.
create table if not exists public.tournament_entrant_coaches (
  entrant_id uuid not null references public.tournament_entrants(id) on delete cascade,
  coach_id   uuid not null references public.coaches(id) on delete cascade,
  primary key (entrant_id, coach_id)
);

create index if not exists tournament_entrant_coaches_coach_idx
  on public.tournament_entrant_coaches (coach_id);

-- MARK: - The fixtures

create table if not exists public.tournament_matches (
  id            uuid primary key default gen_random_uuid(),
  tournament_id uuid not null references public.tournaments(id) on delete cascade,
  round         smallint not null,
  sort_index    smallint not null,

  -- A side is either a known entrant or the winner of an earlier match. Round one of a knockout
  -- and every round-robin fixture use the first; later knockout rounds use the second. Both
  -- nullable on both sides because a bracket padded to a power of two has byes in it, and a bye
  -- is a side that is genuinely nobody.
  a_entrant_id  uuid references public.tournament_entrants(id) on delete cascade,
  b_entrant_id  uuid references public.tournament_entrants(id) on delete cascade,
  a_from_match  uuid references public.tournament_matches(id) on delete cascade,
  b_from_match  uuid references public.tournament_matches(id) on delete cascade,

  a_score       smallint,
  b_score       smallint,

  constraint tournament_matches_round_positive check (round >= 1),
  -- A side is one thing or the other, never both.
  constraint tournament_matches_a_one_source
    check (a_entrant_id is null or a_from_match is null),
  constraint tournament_matches_b_one_source
    check (b_entrant_id is null or b_from_match is null),
  -- A score is a result, and a result has two halves. Half a score is a write that got
  -- interrupted, not a match in progress.
  constraint tournament_matches_score_paired
    check ((a_score is null) = (b_score is null)),
  constraint tournament_matches_score_nonnegative
    check (a_score is null or (a_score >= 0 and b_score >= 0)),
  -- The design's score sheet refuses to save a tie (`saveScore` returns early when the two
  -- numbers are equal), because every format here needs somebody to advance. The rule is
  -- restated at the column so a future caller cannot quietly disagree with the screen.
  constraint tournament_matches_no_draw
    check (a_score is null or a_score <> b_score),
  unique (tournament_id, round, sort_index)
);

create index if not exists tournament_matches_tournament_idx
  on public.tournament_matches (tournament_id, round, sort_index);

-- MARK: - Who can see them
--
-- Scoped by site, and by *membership* rather than by admin: a coach with a court needs to open a
-- draw and put a score on it. That is the same call `groups_update_member` already makes, and
-- the opposite of `sites_update_admin`, where only an admin reshapes the venue itself.

create or replace function private.tournament_ids_for_caller()
returns setof uuid
language sql
stable
security definer
set search_path to ''
as $$
  select t.id from public.tournaments t
  join public.sites s on s.id = t.site_id
  join public.memberships m on m.camp_id = s.camp_id
  where (select auth.uid()) is not null and m.account_id = (select auth.uid());
$$;

create or replace function private.tournament_entrant_ids_for_caller()
returns setof uuid
language sql
stable
security definer
set search_path to ''
as $$
  select e.id from public.tournament_entrants e
  where e.tournament_id in (select private.tournament_ids_for_caller());
$$;

-- Postgres checks function privileges inside an RLS policy against the *invoking* user, not the
-- table owner. Revoking from `authenticated` here would make every policy below fail with
-- "permission denied for function" — which is a lesson this schema has already paid for once.
revoke all on function private.tournament_ids_for_caller() from public;
revoke all on function private.tournament_entrant_ids_for_caller() from public;
grant execute on function private.tournament_ids_for_caller() to authenticated;
grant execute on function private.tournament_entrant_ids_for_caller() to authenticated;

alter table public.tournaments                 enable row level security;
alter table public.tournament_entrants         enable row level security;
alter table public.tournament_entrant_players  enable row level security;
alter table public.tournament_entrant_coaches  enable row level security;
alter table public.tournament_matches          enable row level security;

drop policy if exists tournaments_member on public.tournaments;
create policy tournaments_member on public.tournaments
  for all
  using (site_id in (select private.site_ids_for_caller()))
  with check (site_id in (select private.site_ids_for_caller()));

drop policy if exists tournament_entrants_member on public.tournament_entrants;
create policy tournament_entrants_member on public.tournament_entrants
  for all
  using (tournament_id in (select private.tournament_ids_for_caller()))
  with check (tournament_id in (select private.tournament_ids_for_caller()));

drop policy if exists tournament_entrant_players_member on public.tournament_entrant_players;
create policy tournament_entrant_players_member on public.tournament_entrant_players
  for all
  using (entrant_id in (select private.tournament_entrant_ids_for_caller())
         and player_id in (select private.player_ids_for_caller()))
  with check (entrant_id in (select private.tournament_entrant_ids_for_caller())
              and player_id in (select private.player_ids_for_caller()));

drop policy if exists tournament_entrant_coaches_member on public.tournament_entrant_coaches;
create policy tournament_entrant_coaches_member on public.tournament_entrant_coaches
  for all
  using (entrant_id in (select private.tournament_entrant_ids_for_caller())
         and coach_id in (select private.coach_ids_for_caller()))
  with check (entrant_id in (select private.tournament_entrant_ids_for_caller())
              and coach_id in (select private.coach_ids_for_caller()));

drop policy if exists tournament_matches_member on public.tournament_matches;
create policy tournament_matches_member on public.tournament_matches
  for all
  using (tournament_id in (select private.tournament_ids_for_caller()))
  with check (tournament_id in (select private.tournament_ids_for_caller()));

-- RLS is not the whole story — grants are separate, and creating a table in `public` grants
-- nothing to anyone. Eight objects in this schema once answered 42501 for exactly this reason. A
-- policy on a table nobody can select from is a lock on a door with no handle.
grant select, insert, update, delete on public.tournaments                to authenticated;
grant select, insert, update, delete on public.tournament_entrants        to authenticated;
grant select, insert, update, delete on public.tournament_entrant_players to authenticated;
grant select, insert, update, delete on public.tournament_entrant_coaches to authenticated;
grant select, insert, update, delete on public.tournament_matches         to authenticated;

commit;
