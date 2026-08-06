-- Seed the data that design section 8 ("Sycamore 3a System.dc.html") depicts.
--
-- Target state: one camp, "UCLA Tennis Camp" (tennis, invite SYC-4821), with two
-- venues -- Sycamore (6 coaches, 6 groups, 50 kids) and LATC (4 coaches, 6 groups,
-- 50 kids, i.e. "2 short") -- 14 staff (2 admins, 4 unassigned), 100 kids, today's
-- courts, today's schedule and the inbox.
--
-- This migration is DATA ONLY. It creates no tables and alters no columns.
-- Every statement is idempotent: re-running it is a no-op.
--
-- Two representation notes, because the schema has no home for them:
--   * schedule_blocks has no notes column, so each note a block carries is stored
--     as an inbox_items row of kind 'note' pointing at the group whose court it
--     concerns. There is no schedule_block_id on inbox_items, so the block <-> note
--     link is by group/court and by a hint in the note's detail text.
--   * players has last_initial but no last_name, so the design's "Serene Chu"
--     is stored as first_name 'Serene' + last_initial 'C'.


-- ---------------------------------------------------------------------------
-- 1. The camp
-- ---------------------------------------------------------------------------

insert into camps (name, sport, invite_code, icon, tint)
select 'UCLA Tennis Camp', 'tennis', 'SYC-4821', '🎾', 'moss'
where not exists (select 1 from camps c where c.invite_code = 'SYC-4821');


-- ---------------------------------------------------------------------------
-- 2. Venues
--    The existing site "LTCP" becomes "LATC". "Sunset" is deliberately left
--    alone and unlinked (camp_id stays null) -- the design has exactly 2 venues.
-- ---------------------------------------------------------------------------

update sites set name = 'LATC'
where name = 'LTCP'
  and not exists (select 1 from sites s2 where s2.name = 'LATC');

update sites s set
  camp_id     = (select id from camps where invite_code = 'SYC-4821'),
  subtitle    = '50 kids · 6 coaches',
  icon        = '🌳',
  tint        = 'moss',
  court_count = 6,
  coach_min   = 6,
  coach_max   = 8,
  player_min  = 40,
  player_max  = 60,
  sort_index  = 0
where s.name = 'Sycamore';

update sites s set
  camp_id     = (select id from camps where invite_code = 'SYC-4821'),
  subtitle    = '50 kids · 4 coaches',
  icon        = '🎾',
  tint        = 'citron',
  court_count = 6,
  coach_min   = 6,   -- LATC has 4 coaches, so the app reads "2 short"
  coach_max   = 8,
  player_min  = 40,
  player_max  = 60,
  sort_index  = 1
where s.name = 'LATC';


-- ---------------------------------------------------------------------------
-- 3. Groups: 6 per venue (design 8o / 8r "Sycamore · 6 groups")
-- ---------------------------------------------------------------------------

insert into groups (site_id, name, court_label, rank_order)
select (select id from sites where name = 'LATC'), 'Group ' || g, 'Court ' || g, g
from generate_series(1, 6) g
on conflict (site_id, name) do nothing;

-- Sycamore carries a 7th, empty group ("Group 7" / "Court 7 (fitness)") that the
-- design does not have. Drop it, and the stale court assignment that hangs off it.
delete from court_assignments ca
where ca.group_id in (
  select g.id from groups g
  where g.site_id = (select id from sites where name = 'Sycamore')
    and g.name = 'Group 7'
);

delete from groups g
where g.site_id = (select id from sites where name = 'Sycamore')
  and g.name = 'Group 7'
  and not exists (select 1 from players p       where p.group_id = g.id)
  and not exists (select 1 from assessments a   where a.group_id = g.id)
  and not exists (select 1 from inbox_items i   where i.group_id = g.id)
  and not exists (select 1 from coaches c       where c.group_id = g.id)
  and not exists (select 1 from court_assignments ca where ca.group_id = g.id);


-- ---------------------------------------------------------------------------
-- 4. Staff: 14 total, 2 admins, 4 unassigned
-- ---------------------------------------------------------------------------

-- The design names these two; the seed already had near-matches.
update coaches set name = 'Alex Ramos' where name = 'Alex';
update coaches set name = 'Alina'      where name = 'Ellina';

insert into coaches (name, role, is_admin, active)
select v.name, 'worker', false, true
from (values ('Tom'), ('Dana'), ('Marisol'), ('Priya'), ('Owen'), ('Rhys'), ('Grace')) as v(name)
where not exists (select 1 from coaches c where c.name = v.name);

update coaches c set
  camp_id    = (select id from camps where invite_code = 'SYC-4821'),
  site_id    = (select s.id from sites s where s.name = m.site_name),
  group_id   = (select g.id from groups g
                join sites s2 on s2.id = g.site_id
                where s2.name = m.site_name and g.name = m.group_name),
  role       = m.role,
  role_label = null,                 -- role_label is only legal when role = 'other'
  is_admin   = (m.role = 'admin'),
  is_roaming = m.is_roaming,
  phone      = m.phone,
  active     = true
from (values
  ('Nass',       'Sycamore', 'Group 1', 'admin',  false, '+13105550101'),
  ('Hubert',     'Sycamore', null,      'admin',  true,  '+13105550102'),
  ('Alina',      'Sycamore', 'Group 2', 'worker', false, '+13105550103'),
  ('Tom',        'Sycamore', 'Group 3', 'worker', false, '+13105550104'),
  ('Alex Ramos', 'Sycamore', 'Group 3', 'worker', false, '+13105550105'),
  ('Dana',       'Sycamore', null,      'worker', true,  '+13105550106'),
  ('CJ',         'LATC',     null,      'worker', false, '+13105550107'),
  ('Phil',       'LATC',     null,      'worker', false, '+13105550108'),
  ('Spenser',    'LATC',     null,      'worker', false, '+13105550109'),
  ('Marisol',    'LATC',     null,      'worker', false, '+13105550110'),
  ('Priya',      null,       null,      'worker', false, '+13105550111'),
  ('Owen',       null,       null,      'worker', false, '+13105550112'),
  ('Rhys',       null,       null,      'worker', false, '+13105550113'),
  ('Grace',      null,       null,      'worker', false, '+13105550114')
) as m(name, site_name, group_name, role, is_roaming, phone)
where c.name = m.name;


-- ---------------------------------------------------------------------------
-- 5. Players: 100 kids, 50 per venue
--
--     WORKAROUND, not a fix: the trigger players_seed_rating calls
--     public.seed_rating(), which is declared `SET search_path TO ''` but
--     references `ratings` unqualified. Every insert into players therefore
--     fails with 42P01 relation "ratings" does not exist. That is a live bug in
--     the database -- the app cannot add a player either. Fixing it means
--     editing a function, which is outside this seed's remit, so the trigger is
--     switched off around the inserts here and switched straight back on; the
--     rating rows it would have created are inserted explicitly below instead.
--     The real fix is one line: `insert into public.ratings ...`.
-- ---------------------------------------------------------------------------

alter table players disable trigger players_seed_rating;

-- Tag the named kids that already exist, so external_ref is a stable natural key.
update players p set external_ref = 'syc-serene-c', age = 13, gender = 'F', is_returning = true, updated_at = now()
where p.site_id = (select id from sites where name = 'Sycamore')
  and p.first_name = 'Serene' and p.last_initial = 'C'
  and (p.external_ref is null or p.external_ref = 'syc-serene-c');

update players p set external_ref = 'syc-liam-p', age = 12, gender = 'M', updated_at = now()
where p.site_id = (select id from sites where name = 'Sycamore')
  and p.first_name = 'Liam' and p.last_initial = 'P'
  and (p.external_ref is null or p.external_ref = 'syc-liam-p');

update players p set external_ref = 'syc-austin-z', age = 12, gender = 'M', updated_at = now()
where p.site_id = (select id from sites where name = 'Sycamore')
  and p.first_name = 'Austin' and p.last_initial = 'Z'
  and (p.external_ref is null or p.external_ref = 'syc-austin-z');

-- The named kids the design shows that the seed was missing.
insert into players (first_name, last_initial, age, gender, is_returning, external_ref, site_id)
select v.first_name, v.last_initial, v.age, v.gender, v.is_returning, v.ref,
       (select id from sites where name = 'Sycamore')
from (values
  ('Mia',   'K', 12, 'F', false, 'syc-mia-k'),
  ('Devin', 'P', 13, 'M', false, 'syc-devin-p'),
  ('Jonah', 'R', 12, 'M', false, 'syc-jonah-r'),
  ('Caleb', 'I', 11, 'M', false, 'syc-caleb-i')
) as v(first_name, last_initial, age, gender, is_returning, ref)
where not exists (select 1 from players p where p.external_ref = v.ref);

-- Fill Sycamore up to 50 (2 more) and stand up LATC's 50.
insert into players (first_name, last_initial, age, gender, is_returning, external_ref, site_id)
select v.first_name, v.last_initial, v.age, v.gender, v.is_returning, v.ref, v.site_id
from (
  select
    (array['Ava','Noah','Ivy','Ezra','Nina','Kofi','Lena','Theo','Zara','Milo','Ruby','Arjun','Iris',
           'Kian','Maya','Otto','Sana','Felix','Nadia','Hugo','Talia','Rowan','Esme','Jonas','Marcus',
           'Cato'])[1 + ((i - 1) % 26)]                                   as first_name,
    (array['B','D','F','G','H','K','L','M','N','R','S','T','V','W'])[1 + ((i - 1) % 14)] as last_initial,
    9 + (i % 7)                                                            as age,
    case when i % 2 = 0 then 'F' else 'M' end                              as gender,
    (i % 5 = 0)                                                            as is_returning,
    case when i <= 2
         then 'syc-fill-' || lpad(i::text, 2, '0')
         else 'latc-'     || lpad((i - 2)::text, 2, '0') end               as ref,
    case when i <= 2
         then (select id from sites where name = 'Sycamore')
         else (select id from sites where name = 'LATC') end               as site_id
  from generate_series(1, 52) i
) v
where not exists (select 1 from players p where p.external_ref = v.ref);

alter table players enable trigger players_seed_rating;

-- Every player needs a rating row before the rank pass below. This also covers
-- the rows players_seed_rating would have created had it not been switched off.
insert into ratings (player_id, rating, placed)
select p.id, 1500, false from players p
on conflict (player_id) do nothing;


-- ---------------------------------------------------------------------------
-- 6. Rank order and group partition
--    Design 8o: Group 1 = 8 kids ranked 1-8, Group 2 = 9 ranked 9-17,
--    Group 3 = 8 ranked 18-25. The remaining 25 fill groups 4-6 (9/8/8).
--    The named kids are pinned to the ranks the design shows them at
--    (8i court 1 list, 8o group 2 list); everyone else fills the gaps in a
--    stable order, so re-running produces the identical partition.
-- ---------------------------------------------------------------------------

with sites_in as (
  select id, name from sites where name in ('Sycamore', 'LATC')
),
fixed(site_name, ref, r) as (values
  ('Sycamore', 'syc-serene-c',  1),
  ('Sycamore', 'syc-liam-p',    2),
  ('Sycamore', 'syc-austin-z',  3),
  ('Sycamore', 'syc-mia-k',     4),
  ('Sycamore', 'syc-devin-p',   5),
  ('Sycamore', 'syc-jonah-r',   9),
  ('Sycamore', 'syc-caleb-i',  10)
),
pl as (
  select p.id, p.site_id, p.created_at, f.r as fixed_rank
  from players p
  join sites_in s on s.id = p.site_id
  left join fixed f on f.ref = p.external_ref and f.site_name = s.name
),
free as (
  select id, site_id,
         row_number() over (partition by site_id order by created_at, id) as rn
  from pl
  where fixed_rank is null
),
slots as (
  select s.id as site_id, g.g as r,
         row_number() over (partition by s.id order by g.g) as rn
  from sites_in s
  cross join generate_series(1, 50) as g(g)
  where not exists (
    select 1 from pl where pl.site_id = s.id and pl.fixed_rank = g.g
  )
),
ranked as (
  select id, site_id, fixed_rank as r from pl where fixed_rank is not null
  union all
  select f.id, f.site_id, s.r
  from free f
  join slots s on s.site_id = f.site_id and s.rn = f.rn
),
upd_players as (
  update players p set
    group_id = (
      select gr.id from groups gr
      where gr.site_id = r.site_id
        and gr.rank_order = case
              when r.r <=  8 then 1
              when r.r <= 17 then 2
              when r.r <= 25 then 3
              when r.r <= 34 then 4
              when r.r <= 42 then 5
              else 6
            end
    ),
    updated_at = now()
  from ranked r
  where p.id = r.id
  returning p.id
)
update ratings rt set
  rating     = 2000 - r.r,
  placed     = true,
  last_by    = (select id from coaches where name = 'Nass'),
  last_at    = now() - interval '1 day',   -- 8r: "Rank order published" yesterday
  updated_at = now()
from ranked r
where rt.player_id = r.id;


-- ---------------------------------------------------------------------------
-- 7. Courts today at Sycamore (design 8i)
--    Court 1 Nass, Court 2 Alina, Court 3 Tom. Court 4 is closed ("Net down",
--    "Tom is on it"), which is simply the absence of an assignment; the closure
--    itself is carried by the inbox note below.
-- ---------------------------------------------------------------------------

insert into court_assignments (day, group_id, coach_id)
select current_date, g.id, c.id
from (values ('Group 1', 'Nass'), ('Group 2', 'Alina'), ('Group 3', 'Tom')) as v(group_name, coach_name)
join groups  g on g.name = v.group_name
              and g.site_id = (select id from sites where name = 'Sycamore')
join coaches c on c.name = v.coach_name
on conflict (day, group_id) do nothing;


-- ---------------------------------------------------------------------------
-- 8. Attendance today at Sycamore
--    Jonah Reyes is away (8o user-minus icon, 8r "Jonah Reyes marked away"),
--    Serene Chu leaves at 2:30 (8r).
-- ---------------------------------------------------------------------------

insert into attendance (player_id, day, session, present, leaves_at, noted_by)
select p.id, current_date, 'morning',
       (p.external_ref is distinct from 'syc-jonah-r'),
       case when p.external_ref = 'syc-serene-c' then time '14:30' end,
       (select id from coaches where name = 'Dana')
from players p
where p.site_id = (select id from sites where name = 'Sycamore')
on conflict (player_id, day, session) do nothing;


-- ---------------------------------------------------------------------------
-- 9. Schedule (design 8k) -- 5 blocks at Sycamore, mirrored at LATC so the
--    inbox item "LATC is 2 coaches short / 10:45 match play" has a real block.
-- ---------------------------------------------------------------------------

insert into schedule_blocks (site_id, day, starts_at, ends_at, title, detail, status)
select s.id, current_date, v.starts_at, v.ends_at, v.title, v.detail, v.status
from (values
  (time '08:30', time '09:00', 'Drop-off',        null::text,               'done'),
  (time '09:00', time '10:30', 'Skills rotation', 'Courts 1–3 · 22 players', 'planned'),
  (time '10:30', time '10:45', 'Water & regroup', '15 min',                  'planned'),
  (time '10:45', time '12:00', 'Match play',      null,                      'needs_coach'),
  (time '12:00', time '13:00', 'Lunch',           'Shade lawn',              'planned')
) as v(starts_at, ends_at, title, detail, status)
cross join (select id from sites where name = 'Sycamore') s
where not exists (
  select 1 from schedule_blocks sb
  where sb.site_id = s.id and sb.day = current_date and sb.starts_at = v.starts_at
);

insert into schedule_blocks (site_id, day, starts_at, ends_at, title, detail, status)
select s.id, current_date, v.starts_at, v.ends_at, v.title, v.detail, v.status
from (values
  (time '08:30', time '09:00', 'Drop-off',        null::text,               'done'),
  (time '09:00', time '10:30', 'Skills rotation', 'Courts 1–6 · 50 players', 'planned'),
  (time '10:30', time '10:45', 'Water & regroup', '15 min',                  'planned'),
  (time '10:45', time '12:00', 'Match play',      null,                      'needs_coach'),
  (time '12:00', time '13:00', 'Lunch',           'Shade lawn',              'planned')
) as v(starts_at, ends_at, title, detail, status)
cross join (select id from sites where name = 'LATC') s
where not exists (
  select 1 from schedule_blocks sb
  where sb.site_id = s.id and sb.day = current_date and sb.starts_at = v.starts_at
);


-- ---------------------------------------------------------------------------
-- 10. Inbox (design 8r) plus the schedule-block notes (design 8k)
--
--     The first three 'note' rows are the three notes the 9:00 "Skills rotation"
--     block carries -- 8k previews "Net on 4 is loose — Nass" and counts "+2",
--     and 8r lists all three under "This morning".
--     The last four notes belong to the 10:30, 10:45 and 12:00 blocks.
--     action_label is set only on kind = 'needs_action', per the check constraint.
-- ---------------------------------------------------------------------------

insert into inbox_items (site_id, kind, title, detail, action_label, actor_id, player_id, group_id, resolved, created_at)
select
  (select id from sites where name = v.site_name),
  v.kind, v.title, v.detail, v.action_label,
  (select id from coaches where name = v.actor_name),
  (select id from players where external_ref = v.player_ref),
  (select g.id from groups g
     join sites s2 on s2.id = g.site_id
    where g.name = v.group_name and s2.name = v.group_site),
  false,
  now() - v.age
from (values
  -- Needs you
  ('Sycamore', 'needs_action', 'Austin Zheng → Court 2',    'Nass asked · 8 min ago',                            'Review'::text, 'Nass'::text,   'syc-austin-z'::text, 'Group 2'::text, 'Sycamore'::text, interval '8 minutes'),
  ('LATC',     'needs_action', 'LATC is 2 coaches short',   '10:45 match play · unassigned',                     'Assign',       null,           null,                 null,            null,             interval '25 minutes'),
  -- This morning -- these three are the 9:00 "Skills rotation" block's notes
  ('Sycamore', 'note',         'Nass pinned a note',        'Skills rotation · net on 4 is loose',               null,           'Nass',         null,                 'Group 4',       'Sycamore',       interval '40 minutes'),
  ('Sycamore', 'note',         'Serene Chu leaves at 2:30', 'Mum collects at the gate · today',                  null,           null,           'syc-serene-c',       'Group 1',       'Sycamore',       interval '50 minutes'),
  ('Sycamore', 'note',         'Hubert · Court 2',          'Two in sandals, benched until shoes turn up',       null,           'Hubert',       null,                 'Group 2',       'Sycamore',       interval '55 minutes'),
  ('Sycamore', 'activity',     'Jonah Reyes marked away',   'Dana · 9:12',                                       null,           'Dana',         'syc-jonah-r',        'Group 2',       'Sycamore',       interval '1 hour'),
  -- Yesterday
  ('Sycamore', 'activity',     'Rank order published',      'Sycamore · 6 groups · by Nass',                     null,           'Nass',         null,                 null,            null,             interval '1 day'),
  -- Notes on the later blocks
  ('Sycamore', 'note',         'Shade tent is up',          'Water & regroup · 10:30',                           null,           null,           null,                 null,            null,             interval '35 minutes'),
  ('Sycamore', 'note',         'Alina · Court 2',           'Match play 10:45 · ladders first, then sets to 4',  null,           'Alina',        null,                 'Group 2',       'Sycamore',       interval '18 minutes'),
  ('Sycamore', 'note',         'Tom · Court 4',             'Match play 10:45 · net still down, play on 1–3',    null,           'Tom',          null,                 'Group 4',       'Sycamore',       interval '15 minutes'),
  ('Sycamore', 'note',         'Two nut allergies',         'Lunch · shade lawn · check labels',                 null,           null,           null,                 null,            null,             interval '2 hours')
) as v(site_name, kind, title, detail, action_label, actor_name, player_ref, group_name, group_site, age)
where not exists (
  select 1 from inbox_items i
  where i.site_id = (select id from sites where name = v.site_name)
    and i.kind = v.kind
    and i.title = v.title
);


-- ---------------------------------------------------------------------------
-- 11. profiles / memberships: intentionally NOT seeded.
--     profiles.id is a foreign key onto auth.users.id and auth.users is empty.
--     Auth users can only be created through the Auth Admin API (or the
--     dashboard), not from SQL, and writing straight into auth.users would
--     produce rows that cannot actually sign in. Once Alex Ramos, Nass and
--     Hubert exist as real auth users, insert their profiles, then their
--     memberships against camp SYC-4821, then set coaches.account_id.
-- ---------------------------------------------------------------------------
