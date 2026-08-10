-- ---------------------------------------------------------------------------------------------
-- Putting a coach on a court, as one statement that cannot half-succeed.
-- ---------------------------------------------------------------------------------------------
--
-- `SupabaseRepository.assignStaff` moved a coach onto a court with two PATCHes:
--
--     PATCH coaches?group_id=eq.<court>&id=neq.<coach>   set group_id = null, site_id = null
--     PATCH coaches?id=eq.<coach>                        set group_id = <court>, ...
--
-- one to take the incumbent off, one to put the new coach on. Both are governed by
-- `coaches_update_self_or_admin`, which permits an update when the row is your own *or* you are
-- an admin of its camp.
--
-- THE BUG THIS CLOSES. A `using` clause is not a refusal. PostgREST applies it as a row filter,
-- so an update the policy will not allow matches zero rows and answers 204 — the same answer as
-- an update that had nothing to do. `SupabaseRepository+SectionEight.swift:752-772` already has
-- this written down for the read path (`missingOrRefused`); this is the same shape on a write,
-- and the pair of statements is what makes it dangerous rather than merely quiet:
--
--   A worker holds Court 1. They open the picker and tap an admin. Statement one matches their
--   own row — they are the incumbent — so they come off Court 1. Statement two matches nothing,
--   because a worker may not write an admin's row. Neither request failed. Court 1 now has
--   nobody on it, the admin was never assigned, and the app reports success.
--
-- The mirror case is as reachable and corrupts in the other direction. A worker taps *themselves*
-- onto a court an admin is holding: statement one is refused silently, statement two writes their
-- own row, and the court ends up with two coaches. Nothing in the schema forbids that — one coach
-- per court is not a constraint, it is these two statements run in order, and `coaches_group_idx`
-- is a plain btree, not a unique one.
--
-- Reordering the two and checking that the second wrote a row would close the first case and
-- leave the second, because the fix for the second is to undo the write the first already made.
-- Two PATCHes have nothing to undo them with. One function does: both updates land in one
-- transaction, and a `raise` anywhere in it takes both back.
--
-- WHY `security invoker`. The point is not to do this with more authority than the caller has —
-- it is to find out, before committing, that the caller lacked it. RLS still applies inside here
-- exactly as it does over REST, so both updates are still filtered to rows the caller may write.
-- What changes is that a filtered-out row is now *detectable* — `FOUND`, and a second look at the
-- court — and detecting it aborts the transaction rather than returning 204 over a half-done move.
-- `join_camp_by_code` is `security definer` because it must read a camp you are not in yet; this
-- one must not be, and a definer function here would hand any member an admin's write.
--
-- WHAT THIS DELIBERATELY DOES NOT DO. It takes no row locks. Two devices assigning to the same
-- court in the same instant can still interleave between the bump and the check below, and the
-- loser gets a refusal it did not earn rather than a wrong write. `SELECT … FOR UPDATE` would
-- close that, and would introduce a deadlock between two callers cross-assigning on two courts —
-- a worse failure than a retryable one, bought for a race the client's own `serialised(campID)`
-- gate already covers per device. The permission bug above is deterministic and is what this
-- migration is for; concurrency between devices is a separate property and is not claimed here.

-- No parameter has a default, and the client always sends all three. PostgREST resolves an RPC by
-- the argument names present in the body, so a default is an invitation to a second call shape —
-- and `court` in particular must be able to arrive as an explicit null (taking somebody off a
-- court) rather than by omission, which would be a two-argument function that does not exist.
create or replace function public.assign_coach_to_court(
  coach uuid,
  court uuid,
  roaming boolean
)
returns table (coach_id uuid)
language plpgsql
security invoker
set search_path = ''
as $$
declare
  target_site uuid;
  stranded    integer;
begin
  -- Both ends have to be visible before anything is written. Reads are member-scoped
  -- (`coaches_select_member`, `groups_select_member`) where writes are self-or-admin, so a row
  -- that is invisible here is in a camp that is not the caller's, or is not there at all. Zero
  -- rows for that, which is what `assignStaff`'s own guards already say about a stale graph.
  --
  -- `active` because every read of `coaches` in the app filters it (`SupabaseRepository:211`,
  -- `:316`, `+SectionEight:49`, `:221`), and `removeStaff` clears the court on the way out. A
  -- deactivated coach is gone from every screen and must not be assignable from any of them.
  perform 1 from public.coaches c where c.id = coach and c.active;
  if not found then
    return;
  end if;

  if court is not null then
    select g.site_id into target_site from public.groups g where g.id = court;
    if not found then
      return;
    end if;

    -- One coach per court: whoever was there is bumped to no court.
    update public.coaches
       set group_id = null, site_id = null
     where group_id = court and id <> coach;

    -- And then we look again, because the statement above cannot tell us it skipped somebody.
    -- A row the policy will not let this caller write was not refused, it was not matched, and
    -- `GET DIAGNOSTICS` counts what was written rather than what was meant. The select is
    -- member-scoped where the update is self-or-admin, so anybody still standing on this court
    -- is precisely somebody the caller was not allowed to move.
    select count(*) into stranded
      from public.coaches
     where group_id = court and id <> coach;

    if stranded > 0 then
      raise exception 'cannot move the coach already on that court'
        using errcode = '42501';
    end if;
  end if;

  -- `is_roaming` is false on a court and the role's default off it — a coach who is somewhere
  -- specific is by definition not roaming. The default is the caller's to compute rather than
  -- this function's: `Role.roamsByDefault` (`Models.swift:320`) is the one place that decides it,
  -- and a second copy in SQL would be a mirror to drift. It is not a permission, and the policy
  -- above still governs whose row this writes.
  if court is null then
    update public.coaches
       set group_id = null, site_id = null, is_roaming = roaming
     where id = coach;
  else
    update public.coaches
       set group_id = court, site_id = target_site, is_roaming = false
     where id = coach;
  end if;

  -- The row was visible at the top, so it exists and it is in one of the caller's camps. Nothing
  -- matched here therefore means the policy filtered it: the caller is neither this coach nor an
  -- admin of their camp. Raising rolls back the bump above, which is the whole point — the court
  -- keeps the coach it had rather than being emptied on behalf of a move that never happened.
  if not found then
    raise exception 'cannot move that coach' using errcode = '42501';
  end if;

  return query select coach;
end;
$$;

comment on function public.assign_coach_to_court(uuid, uuid, boolean) is
  'Moves a coach onto a court and the incumbent off it, in one transaction. 42501 if the caller '
  'may not write either row, zero rows if the coach or the court is not visible to them.';

-- `errcode 42501` rather than a bare `raise`, because the status is the whole message. PostgREST
-- answers `insufficient_privilege` with HTTP 403 and the default `P0001` with 400, and 403 is
-- what `SupabaseError.isPolicyRefusal` matches on — so the refusal arrives at the client as
-- `SycamoreError.notPermitted`, "Only an admin can do that.", which is the sentence this is.
-- That helper's comment says a row level security refusal "carries no SQLSTATE at all"; it is
-- describing the filter, and remains true. This is the function reporting what the filter did.

-- `create function` grants execute to PUBLIC, which would put this on the anonymous API. Take it
-- back, then hand it to `authenticated` — the same two lines `join_camp_by_code` needed, for the
-- same reason. Nothing server-side assigns a coach, so `service_role` is not given it.
revoke execute on function public.assign_coach_to_court(uuid, uuid, boolean) from public, anon;
grant execute on function public.assign_coach_to_court(uuid, uuid, boolean) to authenticated;

-- No advisor warning here, unlike `join_camp_by_code`: `authenticated_security_definer_function_
-- executable` is about definer functions, and this one is an invoker. It can do nothing the
-- caller could not already do with two PATCHes — it can only decline to do half of it.

-- REQUIRES THE CLIENT CHANGE THAT SHIPS WITH IT. `assignStaff` calls this function instead of
-- issuing the two PATCHes; the old path still works after this migration and still has the bug,
-- so the two must land in the same merge. The unassign path (`toGroup: nil`) goes through here
-- too — it was a single PATCH and had the quieter half of the same problem, telling a worker who
-- tapped "take off court" on an admin that it had worked.
