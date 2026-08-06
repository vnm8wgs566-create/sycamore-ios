-- Everything section 8 added answers `42501 permission denied` over REST.
--
-- Creating a table in `public` does not grant anything to `anon` or `authenticated`. The nine
-- original tables got their grants from whatever set this project up; `camps`, `memberships`,
-- `profiles`, `schedule_blocks` and `inbox_items` never did, and `drop view` + `create view`
-- discarded the grants `today_courts`, `roster_today` and `player_scores` used to have. All
-- eight sit at `REFERENCES, TRIGGER, TRUNCATE` — which is to say, unusable.
--
-- Enabling RLS and writing a policy is only half of it. RLS narrows what a role may see; the
-- grant is what lets the role reach the table at all, and a policy on a table nobody can select
-- from is a lock on a door with no handle. Sign-in, the camp picker, Schedule and the Inbox are
-- all dead until this runs.
--
-- This restores what `mvp_all` was already written to allow rather than loosening anything:
-- every one of these tables has RLS on, and `profiles` additionally has a real own-row policy,
-- so the grant hands `anon` no row that policy would not already have handed it.
--
-- `TRUNCATE` is deliberately NOT granted. The existing tables carry it, which is a footgun
-- nobody needs over a REST API, and there is no reason to copy it onto the new ones.

-- The five new tables.
grant select, insert, update, delete on public.camps           to anon, authenticated;
grant select, insert, update, delete on public.memberships     to anon, authenticated;
grant select, insert, update, delete on public.profiles        to anon, authenticated;
grant select, insert, update, delete on public.schedule_blocks to anon, authenticated;
grant select, insert, update, delete on public.inbox_items     to anon, authenticated;

-- The three recreated views. Read-only: each is a join or a window function, and none is
-- updatable. `security_invoker` means they still answer to the caller's RLS on the base tables.
grant select on public.today_courts  to anon, authenticated;
grant select on public.roster_today  to anon, authenticated;
grant select on public.player_scores to anon, authenticated;

-- The original tables were granted select/insert/update but never delete — only
-- `court_assignments` has it. So removing a venue, a group, a staff member or a kid fails, which
-- is `updateVenue`, `removeStaff` and every reorder that clears rows before rewriting them.
grant delete on public.assessments to anon, authenticated;
grant delete on public.attendance  to anon, authenticated;
grant delete on public.coaches     to anon, authenticated;
grant delete on public.feedback    to anon, authenticated;
grant delete on public.groups      to anon, authenticated;
grant delete on public.players     to anon, authenticated;
grant delete on public.ratings     to anon, authenticated;
grant delete on public.sites       to anon, authenticated;

-- So the next table added to this schema does not repeat the whole story.
alter default privileges in schema public
  grant select, insert, update, delete on tables to anon, authenticated;
