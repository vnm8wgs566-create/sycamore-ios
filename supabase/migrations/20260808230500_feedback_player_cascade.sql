-- ---------------------------------------------------------------------------------------------
-- feedback.player_id cascades with the kid it is about.
-- ---------------------------------------------------------------------------------------------
--
-- One constraint changes here, and it has to land before any roster removal ships. `8d` gains a
-- tick list of kids who are not on the new file, and `SycamoreRepository.removePlayers` deletes
-- them for real — the first delete of a `players` row this app has ever performed. Every other
-- foreign key into `players` is already correct for that. Verified against the live catalogue:
--
--   ratings.player_id         on delete cascade
--   attendance.player_id      on delete cascade
--   assessments.player_id     on delete cascade
--   inbox_items.player_id     on delete cascade
--   assessments.opponent_id   on delete set null   -- the *other* kid in a comparison
--   feedback.player_id        on delete SET NULL   -- wrong, and the subject of this file
--
-- WHY SET NULL IS WRONG HERE
--
-- `feedback` carries no `site_id`. Its columns are `id, coach_id, player_id, category, body,
-- resolved, created_at`, so the only routes it has to a camp are the two ids, and its policy
-- (`20260806013152_real_rls.sql:489-499`) says exactly that:
--
--     create policy feedback_member on public.feedback
--       for all to authenticated
--       using (
--         player_id in (select private.player_ids_for_caller())
--         or coach_id in (select private.coach_ids_for_caller())
--       )
--
-- The comment above that policy states the intended invariant in one line: "a row with neither
-- belongs to no camp and is refused rather than made invisible." `WITH CHECK` enforces that
-- against anything a *caller* writes. It does not — cannot — constrain a referential action, and
-- `on delete set null` is a referential action. So deleting a player performs precisely the write
-- the policy refuses:
--
--   * a note about a kid that carries no coach — `coach_id` is nullable and there is no CHECK
--     requiring either end, which is exactly why the policy is written with `or` — is left with
--     both anchors null. No policy matches it, no join reaches it, no API call can read or delete
--     it. It is a permanently invisible row that only the service role can ever see again.
--   * a note that does carry a coach stays readable through the `or` branch, but it is now a note
--     about nobody — a category and a body hanging under a coach's name with its subject erased.
--
-- Neither is a fact worth preserving. Feedback is *about* a child; when the child's enrolment is
-- deleted the note goes with them, which is also the answer `ratings`, `attendance`, `assessments`
-- and `inbox_items` already give.
--
-- CORRECTING A MISAPPLIED PRECEDENT
--
-- `20260808211500_fresh_start_and_camp_isolation.sql:178-182` drew the rule this file departs
-- from, and named this very column as its precedent:
--
--     `assessments.opponent_id` names the other kid in a comparison; `attendance.noted_by`,
--     `ratings.last_by`, `feedback.coach_id` and `assessments.coach_id` name who did something.
--     Those are annotations. When the row they point at goes, the fact stays and the pointer
--     empties — set null. `feedback.player_id` already made exactly this choice, which is the
--     precedent the rest now follow.
--
-- The rule is right and the columns it lists are right. The precedent it cites is not. Every
-- column in that list names the **author** of a fact, or a second party to it — who noted the
-- attendance, who last rated, who wrote the feedback, who the opponent was. `feedback.player_id`
-- names the **subject**: the fact is a note about this child, and with the child gone there is no
-- fact left to keep. It was cited as the pattern precisely because it happened to be `set null`
-- already, not because anyone had argued it should be. This file argues it, and moves it.
--
-- Nothing in the annotation rule changes. `feedback.coach_id` stays `set null`
-- (`20260808211500:215-216`) — a note outlives the coach who wrote it, and always did.
--
-- WHAT THIS DOES NOT DO
--
-- No index is added. `feedback_player_idx on public.feedback (player_id)` has existed since
-- `20260805141707:144`, so the cascade walks an index rather than scanning the table — which is
-- the whole reason that index was created in the same file that noted "`on delete cascade` from
-- `camps` will fan out through every one of these, and an unindexed cascade locks and scans"
-- (`20260805141707:134-135`).
--
-- No data is migrated, and none needs to be: `feedback` is empty at the time of writing — 0 rows,
-- checked — because 20260808211500 started the data over and no screen writes this table yet. If
-- a future replay of this history finds a row with a null `player_id`, it is one that was already
-- unreachable, and this file neither rescues nor removes it. Recovering an invisible row is a
-- service-role job, not a schema change.
--
-- `drop constraint if exists` then `add constraint`, the shape `20260808211500:187-193` and
-- `:215-216` use, so this is replayable by `supabase db reset` against a database at any point in
-- the history. The constraint name is the live one, checked against `pg_constraint` rather than
-- assumed from the column name.

alter table public.feedback drop constraint if exists feedback_player_id_fkey;
alter table public.feedback add constraint feedback_player_id_fkey
    foreign key (player_id) references public.players(id) on delete cascade;

-- The short version, carried on the constraint itself so it reaches anybody reading the schema
-- with `\d feedback` rather than only somebody reading this directory. Dollar-quoted because the
-- text runs over several lines: adjacent single-quoted literals would concatenate here too, but
-- only because of the newlines between them, and a rule that subtle is not one to rely on.
comment on constraint feedback_player_id_fkey on public.feedback is
$$Cascade, not set null: a feedback row is about the player, it is not written by them.
20260808211500:178-182 cited this column as the precedent for its annotations-set-null rule, but
that rule is about the author of a fact and this column is its subject. The argument is in
20260808230500_feedback_player_cascade.sql.$$;
