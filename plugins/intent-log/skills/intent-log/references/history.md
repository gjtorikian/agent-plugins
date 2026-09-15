# Reconstructing intent from history

Use this procedure when the current conversation does not cover the requested
period. Start with `~/.intent-log/staging/*.jsonl` when it exists: those are
prompts captured as typed, already dated and tagged with their repository and
branch, and need none of the transcript work below. For days it does not
cover, read available local history or user-supplied exports with the host's
supported capabilities. This port does not bundle a host-specific extractor
beyond the Pi capture extension.

1. Establish the person, date range, and local timezone. The log is global,
   so every project the person worked in during the range is in scope; use
   session metadata to find them all rather than starting from one
   repository. Worktrees may have their own session locations. `git worktree
   list --porcelain` in a checkout can identify current worktrees, but older
   session metadata may refer to ones already removed.
2. Inspect the actual transcript format before extracting messages. Identify
   human-authored prompts and their timestamps, session IDs, and repository
   paths. A record marked as a user message can still contain injected skill
   instructions or tool content: use provenance and metadata to exclude them.
   On a shared machine, include only the person's own sessions.
3. Include human messages queued while an agent was running. Some histories
   record these separately from ordinary turns. When the same queued event
   later becomes a normal turn, count it once. Prefer message IDs or matching
   text and timestamps within a session; do not deduplicate unrelated asks just
   because their first few words match.
4. Convert timestamps to the person's local timezone, accounting for daylight
   saving time. Sort prompts from every project and parallel session together.
   Divide them at idle gaps longer than five hours. Keep a block crossing
   midnight on the date it began, and merge blocks starting on the same date
   into one entry regardless of repository.
5. Read all the requested blocks before drafting, oldest first. Follow threads
   across dates and repositories, and compare PR titles, branches, diffs, and
   creation times to their preceding requests. Put a later PR tag on the
   original ask, with the PR's `owner/repo` prefix.
6. Extract only supported human intent. A user stating a choice is evidence;
   the agent's suggestion alone is not. Inspect unmatched PRs and other relevant
   sessions before concluding that work originated in a review. A memory of a
   date is a lead to verify, not a reason to overwrite transcript evidence.

Keep raw transcripts and any temporary prompt extracts local, outside every
repository. If staging is needed, use a location under `~/.intent-log/`, such
as `~/.intent-log/staging/`, or an OS temporary directory. Do not copy raw
prompts into the log or into any tracked file, and do not install
capture/reminder hooks as part of ordinary log writing.

When history is missing, write only the supported portion. Explain the gap to
the user, and request the missing dates or decisions if they are necessary to
finish. Do not fabricate a reason from a diff, or assume that a missing prompt
means the agent made the decision.
