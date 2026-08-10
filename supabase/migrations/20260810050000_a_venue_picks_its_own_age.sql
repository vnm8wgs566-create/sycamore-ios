-- A venue picks its own age, not one of three
--
-- `sites.age_band` was a three-valued text column — 'all', 'under_twelve', 'twelve_up' — and the
-- pivot was welded to twelve in the type itself. A camp that splits at ten, or at thirteen, or that
-- runs a nine-to-twelve venue alongside an open one, could not say so. Three answers is not a
-- setting; it is a guess about which camp is asking.
--
-- The replacement is a nullable pair. `age_min` and `age_max` are inclusive bounds and either may be
-- null, which reads as "not asking on that side":
--
--     age_min   age_max    means
--     ------------------------------------------------------------
--     null      null       all ages          (the old 'all')
--     null      11         11 and under      (the old 'under_twelve')
--     12        null       12 and up         (the old 'twelve_up')
--     9         12         nine to twelve    (new, and the point of this)
--
-- Two nullable smallints rather than a pivot-plus-direction pair, which was the shape the request
-- literally described ("over and under" at a chosen age). A pivot cannot express a band closed at
-- both ends, and a camp that has once been able to say "12 & up" asks for "9–12" the same afternoon.
-- It is also the shape the *check* wants: one comparison between two columns, rather than a
-- direction enum that has to be read before either bound means anything.
--
-- ── The old column goes ──────────────────────────────────────────────────────────────────────────
--
-- `age_band` is dropped rather than kept alongside. Left in place it would be a column that still
-- looks authoritative, still has a CHECK defending it, and is wrong the moment anybody picks ten —
-- and the next person to read the schema would have no way to tell which of the two the app
-- believes. There is exactly one reader of this data and it is updated in the same change.
--
-- Backfilled before the drop, so the two venues currently sitting on 'twelve_up' keep their band.

begin;

alter table public.sites
  add column age_min smallint,
  add column age_max smallint;

-- The three old values, said in the new shape. `under_twelve` meant "eleven and under", so its
-- ceiling is 11 and not 12 — the name counted up to the pivot, the bound counts to the last age
-- actually admitted.
update public.sites set age_min = 12 where age_band = 'twelve_up';
update public.sites set age_max = 11 where age_band = 'under_twelve';

alter table public.sites drop constraint if exists sites_age_band_known;
alter table public.sites drop column age_band;

-- A band that admits nobody is a venue that can never be filled, and it is far more likely to be a
-- slip than an intention. Ordered rather than merely present, so `9–12` is accepted and `12–9` is
-- refused at the column rather than discovered when a roster lands and nothing is dealt.
alter table public.sites
  add constraint sites_age_bounds_ordered
  check (age_min is null or age_max is null or age_min <= age_max);

-- Three to twenty-one. Not arbitrary: below three there is no camp, and the upper bound is where
-- a junior programme stops being one. Wide enough that no real camp meets it, narrow enough that a
-- fat-fingered 120 is refused here rather than drawn on a chip as "120 & up".
alter table public.sites
  add constraint sites_age_min_sane check (age_min is null or (age_min between 3 and 21)),
  add constraint sites_age_max_sane check (age_max is null or (age_max between 3 and 21));

comment on column public.sites.age_min is
  'Inclusive lower age bound; null means the venue is not asking on that side.';
comment on column public.sites.age_max is
  'Inclusive upper age bound; null means the venue is not asking on that side.';

commit;
