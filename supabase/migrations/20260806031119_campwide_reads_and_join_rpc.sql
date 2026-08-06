-- Closes the one carve-out `20260806013152_real_rls.sql` wrote down and could not fix, and says
-- why the camp-wide Inbox needed no schema of its own.
--
-- THE CARVE-OUT. That migration left `camps` readable by every signed-in user:
--
--     create policy camps_select_signed_in on public.camps
--       for select to authenticated using (true);
--
-- with the reason attached — `joinCamp` reads a camp by invite code *before* the membership
-- exists, so a members-only select makes joining permanently impossible. The cost is that any
-- account, anywhere, can `GET /rest/v1/camps?select=*` and walk away with every camp's name and
-- every camp's invite code. An invite code you can read is not an invite.
--
-- Row level security cannot tell "look this one camp up by its code" from "list them all": a
-- policy sees the row, never the caller's `where`. So the lookup has to stop being a select. This
-- migration replaces it with `public.join_camp_by_code(text)`, which takes the code, joins the
-- caller, and hands back nothing but the camp's id — and then narrows the select policy to
-- members, which is what every other table in the schema already says.
--
-- REQUIRES A CLIENT CHANGE, and does not work without it. `SupabaseRepository.joinCamp` still
-- runs `camps?invite_code=eq.SYC-4821`, which after this migration matches no policy and returns
-- `[]` — read by the app as `unknownInviteCode`. The replacement is in the pull request that
-- carries this file; it is six lines, and it must land in the same merge.

-- ---------------------------------------------------------------------------
-- 1. join_camp_by_code — the only way into a camp you are not in yet
-- ---------------------------------------------------------------------------
-- `security definer`, because the whole point is to do something the caller may not: read a camp
-- row they cannot see and write a membership for it. Everything that makes that safe rather than
-- convenient is below, and each line is load-bearing.
--
--   * It takes the code and nothing else. There is no `account_id` parameter, because a definer
--     function that accepts whose membership to create is an account-takeover endpoint with a
--     friendly name. The account is `(select auth.uid())`, derived, never passed.
--   * It checks `auth.uid()` itself rather than trusting that the grant below is the only door.
--   * `set search_path = ''` so a schema planted on the caller's path cannot make `camps` mean
--     something else. Every reference is schema-qualified because of it.
--   * It returns the camp's id and no other column. Not the name, not the code, not `created_at`
--     — a function that answered with the row would be the enumeration hole again, wearing a hat.
--   * Every failure returns zero rows: no such code, a code that is not even code-shaped, no
--     signed-in caller. One shape of answer, so a wrong guess cannot be told from a camp that
--     exists but refused, and no `raise` quotes the code back.
--   * Idempotent. `on conflict do nothing` against `memberships_account_id_camp_id_key`, so
--     pasting your own code a second time returns the same camp and leaves your role alone —
--     an admin who does it stays an admin, where an upsert would demote them to `worker`.
--
-- `returns table (camp_id uuid)` rather than `returns uuid`: PostgREST answers a scalar function
-- with a bare JSON scalar and a set-returning one with an array of objects, and `PostgRESTClient`
-- decodes every response as an array. A shape the existing client can already read is worth more
-- than the tidier signature.
create or replace function public.join_camp_by_code(code text)
returns table (camp_id uuid)
language plpgsql
security definer
set search_path = ''
as $$
  -- `camp_id` is both this function's out-parameter and a column of `memberships`. Postgres
  -- resolves the collision toward the column, which is what the insert below wants; saying so
  -- explicitly means a later editor cannot be surprised by it.
  #variable_conflict use_column
declare
  caller_id uuid := (select auth.uid());
  tidy_code text;
  found_camp uuid;
begin
  -- Belt to the grant's braces. `anon` cannot reach this function at all, but a definer function
  -- that infers the caller from a null is one refactor away from joining nobody to everything.
  if caller_id is null then
    return;
  end if;

  -- The same normalisation `SupabaseRepository.formattedInviteCode` does, because the code
  -- arrives as the coach typed it: "syc 4821", "syc-4821", "SYC4821" are one camp. Anything that
  -- is not three letters and four digits cannot match `camps_invite_code_check` either, so it is
  -- refused here rather than being sent to the index.
  tidy_code := upper(regexp_replace(coalesce(code, ''), '[^a-zA-Z0-9]', '', 'g'));
  if tidy_code !~ '^[A-Z]{3}[0-9]{4}$' then
    return;
  end if;
  tidy_code := left(tidy_code, 3) || '-' || right(tidy_code, 4);

  select c.id into found_camp from public.camps c where c.invite_code = tidy_code;
  if found_camp is null then
    return;
  end if;

  -- A code hands out the lowest useful permission, exactly as the old client path did; an admin
  -- promotes from Setup. `memberships_insert_self_or_admin` says the same thing, and this
  -- function must not be the way around it.
  insert into public.memberships (account_id, camp_id, role)
  values (caller_id, found_camp, 'worker')
  on conflict (account_id, camp_id) do nothing;

  return query select found_camp;
end;
$$;

comment on function public.join_camp_by_code(text) is
  'Joins the calling account to the camp holding this invite code and returns its id. Zero rows '
  'for any failure. The only read of `camps` that does not require membership.';

-- `create function` grants execute to PUBLIC, which would put this on the anonymous API. Take it
-- back, then hand it to `authenticated` — the role the app actually calls it as. Not
-- `service_role`: nothing server-side joins a camp, and a definer function that writes
-- memberships does not need a second caller.
revoke execute on function public.join_camp_by_code(text) from public, anon;
grant execute on function public.join_camp_by_code(text) to authenticated;

-- This grant raises `authenticated_security_definer_function_executable` in Supabase's security
-- advisor, and the warning is correct about the facts: a signed-in user can call a definer
-- function over `/rest/v1/rpc/`. It is also the only shape that works. `security invoker` cannot
-- read a camp you are not yet in — that is the entire problem — and revoking the grant leaves a
-- function nobody can call. The warning is accepted here, and everything it is warning about is
-- answered above: no account parameter, an `auth.uid()` check in the body, an empty search path,
-- one column out, and one shape of failure.

-- WHAT IS STILL OPEN, said out loud. An invite code is `[A-Z]{3}-[0-9]{4}`, and `Camp.inviteCode`
-- takes the letters from the camp's name — so somebody who knows a camp is called "Sycamore" has
-- ten thousand guesses to make, and this function will tell them when one lands by joining them.
-- That is strictly better than today, where the code is simply readable, and it is still weak.
-- Closing it properly means longer, random codes (a `Camp.inviteCode` change) or a throttle table
-- keyed on the caller; neither belongs in this migration, and neither is pretended to be here.

-- ---------------------------------------------------------------------------
-- 2. camps select, narrowed to members
-- ---------------------------------------------------------------------------
-- One policy in, one policy out, so `camps` still has exactly one policy per command and the
-- `multiple_permissive_policies` advisor stays quiet. `(select auth.uid())` is inside
-- `private.camp_ids_for_caller()`, so it is evaluated once per statement rather than once per row.
--
-- Every column this filters on is already indexed, checked against `pg_indexes` rather than
-- assumed: `camps.id` is `camps_pkey`, and the helper finds its rows by `memberships.account_id`
-- (`memberships_account_idx`) and returns `camp_id`. The lookup inside the function above uses
-- `camps_invite_code_key`, and its `on conflict` target is `memberships_account_id_camp_id_key`.
-- Nothing new is needed, and an index nobody reads is write cost the advisors already complain
-- about elsewhere in this schema.
--
-- Three reads of `camps` survive this untouched, because all three are already by a camp you are
-- in: `memberships(forAccount:)`, `camp(id:)`, and the ownership check in `+Graph.swift`.
-- `createCamp` is unaffected too — it inserts, and does not read the camp back until after the
-- membership row that makes it its author's.

drop policy if exists camps_select_signed_in on public.camps;
drop policy if exists camps_select_member on public.camps;
create policy camps_select_member on public.camps
  for select to authenticated
  using (id in (select private.camp_ids_for_caller()));

-- ---------------------------------------------------------------------------
-- 3. The camp-wide Inbox needs no schema, and here is why
-- ---------------------------------------------------------------------------
-- `8r` draws "LATC is 2 coaches short" while the reader is standing on Sycamore, so the Inbox
-- spans the camp's venues rather than one of them. The app read it per venue and picked the venue
-- by falling back to the camp's first — a client-side answer to a question the read should have
-- been asking.
--
-- It is asked properly now, and in SQL that already existed: `inbox_items.site_id` → `sites` →
-- `sites.camp_id`, which PostgREST expresses as
--
--     inbox_items?select=*,sites!inner(camp_id)&sites.camp_id=eq.<camp>&order=created_at.desc
--
-- the same embedded-join shape `ratings`, `attendance` and the player ownership check in
-- `+Graph.swift` already use. So: no view.
--
-- Not a view deliberately. `today_courts` is the cautionary tale sitting in this schema already —
-- a `drop view … create view` reset its grants, `authenticated` lost `select`, and the app has
-- been answered `42501` on it ever since. A view would also need `security_invoker = true` or it
-- would read `inbox_items` as its owner and hand every camp's Inbox to everyone, which is the bug
-- this migration is closing on the next table over.
--
-- The read is covered by `inbox_items_site_created_idx (site_id, created_at desc)` per venue and
-- `sites_camp_idx (camp_id, sort_index)` to find the venues. No index is added for the merged
-- sort across venues: a camp has a handful of sites, and a btree on `created_at` alone would be
-- written on every row for a sort of a few dozen.
--
-- `inbox_items_member` already scopes the rows to venues of camps you are in, so a camp-wide read
-- is not a wider one — it is the same rows, asked for in one request instead of one per venue.

-- ---------------------------------------------------------------------------
-- WHAT HAPPENS BEFORE ANY USER EXISTS
-- ---------------------------------------------------------------------------
-- `auth.users`, `profiles` and `memberships` are all still empty, and nothing here grants `anon`
-- anything, so:
--
--   * An unauthenticated caller — a stolen publishable key on its own — now reads zero rows from
--     `camps` as well as from everything else, and cannot name `join_camp_by_code` at all. Before
--     this migration it read nothing either; the account that had *signed in* was the one that
--     could read every camp.
--   * A signed-in account with no memberships sees no camps. That is the camp picker's empty
--     state, which is what it drew before too — the difference is that the rows are now invisible
--     rather than merely unlisted.
--   * The way in is the invite code, and it is now the only way in: `join_camp_by_code('SYC-4821')`
--     writes the `worker` membership, returns the camp id, and the whole camp — 3 venues, 12
--     courts, 100 players — becomes readable in the same breath. Nobody is an admin of that camp
--     until one is promoted with the service role key:
--
--       update public.memberships set role = 'admin', role_label = null
--        where camp_id = '4f8ab779-f077-4841-a11a-a8369ae5f3a2';
--
--   * The pre-existing `Sunset` site with a null `camp_id` is still visible to nobody, and is
--     still dead weight.
