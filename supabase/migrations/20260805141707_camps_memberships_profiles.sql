-- The app's domain model and this database were built from opposite ends and do not meet.
--
-- The app is organised Camp -> Venue -> Group -> Player, with an Account holding Memberships
-- that carry a Role. The database starts at `sites` — there is no camp, no membership, and no
-- account profile — and `sites` carries two of the thirteen fields `Venue` does.
--
-- Nothing in section 8 works until that closes: `8t Camp settings` is camp-scoped, `8u Manage
-- camps` lists memberships, `8s Profile` reads an account, and every screen filters by venue.
--
-- Conventions follow the existing schema: uuid keys from `gen_random_uuid()`, `timestamptz`
-- audit columns, `text` with a CHECK for closed sets. New columns are added with defaults so
-- the 44 players, 7 groups, 7 coaches and 3 sites already here stay valid.

-- ---------------------------------------------------------------------------------------
-- Camps
-- ---------------------------------------------------------------------------------------

create table if not exists public.camps (
  id           uuid primary key default gen_random_uuid(),
  name         text not null check (char_length(name) between 1 and 80),
  sport        text not null default 'tennis'
               check (sport in ('tennis', 'soccer', 'basketball', 'swim', 'other')),
  -- `SYC-4821` in the design. Unique because `joinCamp(inviteCode:)` looks a camp up by it.
  invite_code  text not null unique check (invite_code ~ '^[A-Z]{3}-[0-9]{4}$'),
  icon         text not null default '🎾',
  tint         text not null default 'moss' check (tint in ('moss', 'sky', 'citron')),
  created_at   timestamptz not null default now()
);

-- ---------------------------------------------------------------------------------------
-- Accounts
-- ---------------------------------------------------------------------------------------
--
-- `auth.users` owns identity; this owns the profile the app shows. Split because the app lets
-- someone edit their display name and emergency phone, and `auth.users` is not ours to extend.

create table if not exists public.profiles (
  id                    uuid primary key references auth.users (id) on delete cascade,
  email                 text not null,
  display_name          text not null default '',
  emergency_phone       text,
  notifications_enabled boolean not null default true,
  avatar_url            text,
  created_at            timestamptz not null default now(),
  updated_at            timestamptz not null default now()
);

-- ---------------------------------------------------------------------------------------
-- Memberships
-- ---------------------------------------------------------------------------------------
--
-- "Your permissions come from the camp, not the login. The same account can be an admin at one
-- camp and a coach at another." — the app's own verify screen. That sentence is why role lives
-- here and not on `profiles`.

create table if not exists public.memberships (
  id          uuid primary key default gen_random_uuid(),
  account_id  uuid not null references public.profiles (id) on delete cascade,
  camp_id     uuid not null references public.camps (id) on delete cascade,
  role        text not null default 'worker'
              check (role in ('admin', 'worker', 'trainer', 'other')),
  -- Only `other` carries a free-text label, matching `Role.other(label:)`.
  role_label  text check (role_label is null or role = 'other'),
  created_at  timestamptz not null default now(),

  -- `joinCamp` is documented idempotent — "joining twice returns the same membership".
  -- The constraint is what makes that true rather than the client remembering to check.
  unique (account_id, camp_id)
);

create index if not exists memberships_account_idx on public.memberships (account_id);
create index if not exists memberships_camp_idx    on public.memberships (camp_id);

-- ---------------------------------------------------------------------------------------
-- Sites become Venues
-- ---------------------------------------------------------------------------------------

alter table public.sites
  add column if not exists camp_id     uuid references public.camps (id) on delete cascade,
  add column if not exists subtitle    text,
  add column if not exists icon        text not null default '🌳',
  add column if not exists tint        text not null default 'moss',
  add column if not exists coach_min   integer not null default 4,
  add column if not exists coach_max   integer not null default 8,
  add column if not exists player_min  integer not null default 40,
  add column if not exists player_max  integer not null default 60,
  add column if not exists sort_index  integer not null default 0;

do $$ begin
  alter table public.sites add constraint sites_tint_check
    check (tint in ('moss', 'sky', 'citron'));
exception when duplicate_object then null; end $$;

do $$ begin
  alter table public.sites add constraint sites_ranges_ordered
    check (coach_min <= coach_max and player_min <= player_max);
exception when duplicate_object then null; end $$;

create index if not exists sites_camp_idx on public.sites (camp_id, sort_index);

-- ---------------------------------------------------------------------------------------
-- Coaches become Staff
-- ---------------------------------------------------------------------------------------

alter table public.coaches
  add column if not exists camp_id    uuid references public.camps (id) on delete cascade,
  add column if not exists site_id    uuid references public.sites (id) on delete set null,
  add column if not exists group_id   uuid references public.groups (id) on delete set null,
  add column if not exists account_id uuid references public.profiles (id) on delete set null,
  add column if not exists role       text not null default 'worker',
  add column if not exists role_label text,
  add column if not exists phone      text,
  add column if not exists is_roaming boolean not null default false;

-- Backfilled from the boolean this replaces, so the seven coaches already here keep the
-- permissions they had. `is_admin` stays for now rather than being dropped mid-flight — the
-- two are reconciled once nothing reads it.
update public.coaches set role = 'admin' where is_admin and role <> 'admin';

do $$ begin
  alter table public.coaches add constraint coaches_role_check
    check (role in ('admin', 'worker', 'trainer', 'other'));
exception when duplicate_object then null; end $$;

create index if not exists coaches_camp_idx    on public.coaches (camp_id);
create index if not exists coaches_site_idx    on public.coaches (site_id);
create index if not exists coaches_group_idx   on public.coaches (group_id);
create index if not exists coaches_account_idx on public.coaches (account_id);

-- ---------------------------------------------------------------------------------------
-- Foreign keys the existing schema left unindexed
-- ---------------------------------------------------------------------------------------
--
-- Ten of them. Free at 44 players; the reason to do it now is that `on delete cascade` from
-- `camps` will fan out through every one of these, and an unindexed cascade locks and scans.

create index if not exists assessments_coach_idx      on public.assessments (coach_id);
create index if not exists assessments_group_idx      on public.assessments (group_id);
create index if not exists assessments_opponent_idx   on public.assessments (opponent_id);
create index if not exists attendance_noted_by_idx    on public.attendance (noted_by);
create index if not exists court_assign_coach_idx     on public.court_assignments (coach_id);
create index if not exists court_assign_group_idx     on public.court_assignments (group_id);
create index if not exists feedback_coach_idx         on public.feedback (coach_id);
create index if not exists feedback_player_idx        on public.feedback (player_id);
create index if not exists players_group_idx          on public.players (group_id);
create index if not exists ratings_last_by_idx        on public.ratings (last_by);

-- ---------------------------------------------------------------------------------------
-- Views: SECURITY INVOKER, and stop hardcoding one venue
-- ---------------------------------------------------------------------------------------
--
-- All three were SECURITY DEFINER, which the linter flags at ERROR: they run with the creator's
-- rights and ignore the caller's RLS entirely. Once these tables carry a real per-camp policy
-- that would hand every row of every camp to anyone who queried a view. `security_invoker`
-- makes them honour the caller instead, which is what they were always meant to do.
--
-- `today_courts` additionally filtered `s.name = 'Sycamore'` — a hardcoded venue name. The app
-- has two venues in the design alone, so the filter becomes a column the caller selects on.

drop view if exists public.today_courts;
create view public.today_courts with (security_invoker = true) as
  select g.site_id,
         g.id           as group_id,
         g.name         as group_name,
         g.court_label,
         g.rank_order,
         c.id           as coach_id,
         c.name         as coach_name,
         (select count(*)
            from players p
            join attendance a on a.player_id = p.id
           where p.group_id = g.id and a.day = current_date and a.present) as players_here
    from groups g
    left join court_assignments ca on ca.group_id = g.id and ca.day = current_date
    left join coaches c on c.id = ca.coach_id
   order by g.rank_order;

drop view if exists public.roster_today;
create view public.roster_today with (security_invoker = true) as
  select p.id, p.site_id, p.group_id,
         p.first_name, p.last_initial, p.age, p.gender, p.is_returning,
         g.name as group_name, g.court_label, g.rank_order,
         r.rating, r.placed, r.n_events,
         c.name as last_rated_by, r.last_at,
         a.leaves_at
    from players p
    left join ratings r on r.player_id = p.id
    left join groups  g on g.id = p.group_id
    left join coaches c on c.id = r.last_by
    join attendance a on a.player_id = p.id and a.day = current_date and a.present
   order by r.rating desc nulls last;

drop view if exists public.player_scores;
create view public.player_scores with (security_invoker = true) as
  select p.id, p.site_id,
         round((percent_rank() over (partition by p.site_id order by r.rating) * 10)::numeric, 1) as score
    from players p
    join ratings r on r.player_id = p.id
   where r.placed;

-- ---------------------------------------------------------------------------------------
-- Function hardening
-- ---------------------------------------------------------------------------------------
--
-- Both flagged for a mutable `search_path`: without it, whoever calls the function decides
-- which schema `players` means, which is the whole shape of a search-path attack.

alter function public.touch_updated_at() set search_path = '';
alter function public.seed_rating()      set search_path = '';

-- `rls_auto_enable` is a SECURITY DEFINER function reachable over the public REST API by both
-- `anon` and `authenticated` — anyone with the publishable key could call it. It is a
-- maintenance helper, not an endpoint.
revoke execute on function public.rls_auto_enable() from public, anon, authenticated;

-- ---------------------------------------------------------------------------------------
-- RLS
-- ---------------------------------------------------------------------------------------
--
-- The three new tables adopt the `mvp_all` placeholder the other eleven carry, so the whole
-- schema still tightens in one pass. `profiles` is the exception: it is keyed on
-- `auth.users.id`, so the real policy is available today at no cost and there is no reason to
-- leave a person's email and phone readable by everyone.
--
-- `(select auth.uid())` rather than a bare `auth.uid()` — wrapped in a sub-select Postgres
-- evaluates it once for the statement instead of once per row.

alter table public.camps       enable row level security;
alter table public.memberships enable row level security;
alter table public.profiles    enable row level security;

drop policy if exists mvp_all on public.camps;
create policy mvp_all on public.camps for all using (true);

drop policy if exists mvp_all on public.memberships;
create policy mvp_all on public.memberships for all using (true);

drop policy if exists profiles_own_row on public.profiles;
create policy profiles_own_row on public.profiles
  for all using ((select auth.uid()) = id) with check ((select auth.uid()) = id);
