---
name: intent-log
description: Write, update, or backfill one person's global daily intent log at ~/.intent-log, covering their requests and decisions across every repository, with verified pull-request status. Use when asked for an intent log, to log today's asks and decisions, or to catch a teammate up on a burst of agent-assisted work and why it happened.
---

# Intent Log

Keep `~/.intent-log/intent-log.md` as one person's short daily account of what
they wanted, why they wanted it, and where the work got to, across every
repository they touch. Git records the code changes in each repository; the
log records human intent in one place. `INTENT_LOG_HOME` overrides the
directory. The log belongs to one person: never write another person's entries.

## Establish the evidence

1. Read the existing log. If the directory or file is missing, create it with
   the header in [references/format.md](references/format.md). Use the
   requested date range and timezone, and the person's GitHub login; infer
   them from reliable context when possible. Ask only for missing information
   that affects the entry.
2. Read the person's actual requests and decisions. If
   `~/.intent-log/staging/` holds `YYYY-MM-DD.jsonl` files, read them
   first: each line is one prompt the person typed, with `ts`, `cwd`,
   `repo`, `branch`, `session`, and `host`, captured by a host
   integration such as the bundled Pi extension. Fill gaps from the current
   conversation, available local history, or transcripts they supplied, using
   the host's history and file capabilities; no particular session directory
   or transcript format is required. Work in several repositories on one day
   belongs in that day's single entry. For historical reconstruction, read
   [references/history.md](references/history.md).
3. Verify PR state across all of the person's repositories. For GitHub, run
   this from any directory, setting the date to the earliest day being
   written and increasing the limit or narrowing with `--owner` when the
   result reaches the limit:

   ```sh
   gh search prs --author @me --created ">=2026-09-10" --limit 500 --json number,repository,state,title,createdAt
   ```

   Each result's `state` is `open`, `closed`, or `merged`, and `repository`
   carries `nameWithOwner`. Convert UTC timestamps to the person's local
   timezone. Match PRs to the requests that produced them using their content,
   branch, and conversation, rather than proximity in time alone. Inspect
   unmatched PRs before assigning them to review work. If access is
   unavailable, record the verification gap in the handoff to the user rather
   than inventing a state.

When only code or PR descriptions survive, they establish changes and status,
not the person's reasoning. Do not turn them into first-person decisions.
Continue with supported entries and tell the user which history is missing.
Missing evidence does not prove that an unlogged choice was the agent's idea.

## Write the entry

Read [references/format.md](references/format.md) for the format and example.

- Keep one short list per day, oldest first, with new entries at the bottom.
  Put an ask on the day it was made, even if its PR shipped later; update the
  existing tag rather than repeating the PR in a new entry.
- Write one concrete ask per bullet, at most 20 words including its PR tag.
  Put the reasoning below it, rather than adding background to the bullet.
  Keep each day at most 400 words.
- Use the person's plain, first-person voice. Prefer intent such as "wanted",
  "decided", or "changed my mind". Name the actual feature or fields instead
  of vague references such as "the two things".
- Add two-space-indented `**why:**` and `**I decided:**` sub-lines only when
  the person's own words support them. The first explains what prompted the
  ask; the second records a choice, especially a rejected alternative.
  Neither sub-line repeats a PR tag.
- Tag each PR exactly once, with its repository: `` `owner/repo#26` `` for
  merged, `` `owner/repo#61 open` `` for open, and `` `owner/repo#7 dropped` ``
  for closed without merging. The tag is the ask's only repository context;
  do not add a separate repository note to the bullet. An ask with no PR has
  no tag and names no repository. If a merged PR removed or abandoned an
  idea, say that in the bullet.
- Attribute ideas from reviewers or teammates inside the person's own bullets.
  Name colleagues when relevant; refer to people affected by a bug generically
  unless their identity is necessary and appropriate for the log. Never paste
  raw private transcripts, credentials, sign-in links, or production records
  into the entry.
- Omit routine tests, review rounds, restarts, and iteration history. Preserve
  human reversals as ordinary intent bullets. Use the optional tails
  `*Dropped: ...*`, `*Postponed: ...*`, `*From review: ...*`, and
  `*Could use a hand: ...*` only when they add an outcome or actionable need.
  Use "From review" only when evidence supports that origin.

## Verify and deliver

The bundled checker uses Ruby 2.7 or newer and its standard library. Resolve
[scripts/check.rb](scripts/check.rb) relative to this skill's installed
directory. In examples below, replace `<skill-dir>` with that resolved path;
it is not a host-provided variable. The checker reads the default log path,
so it can run from any directory.

```sh
# Validate the log against the person's live GitHub PRs:
ruby "<skill-dir>/scripts/check.rb"

# Limit live PR coverage to one or more owners:
ruby "<skill-dir>/scripts/check.rb" --owner myorg --owner mylogin
```

The checker fetches every PR the person created since the log's first entry
and reports PRs in no entry, repeated tags, incorrect status markers, tags
outside the fetched evidence, chronology and weekday errors, a missing initial
year, long bullets or days, and long lines. An intentionally partial log needs
an explicit evidence snapshot or a narrower `--owner` or `--since` scope; see
[references/verification.md](references/verification.md) for scope, offline
input, custom paths, and rewrapping. Do not fill gaps with invented intent just
to satisfy a check.

If Ruby or PR access is unavailable, apply the same checks using the evidence
and tools available, and state which automated or status checks could not run.
After every write, inspect the diff for supported intent, brevity, and privacy.
Then move each staging file for a day you wrote up into
`~/.intent-log/staging/logged/`, so the startup reminder stops counting it.
Never delete, publish, or quote staging files wholesale; they are raw prompts.
Return the log path, the covered dates, and any unresolved evidence gaps.

The log lives outside any project. Do not copy it into a repository, commit
it, or publish it unless the user asks. Prompt capture is a host integration:
on Pi, the extension bundled with this plugin stages prompts after each agent
run and reminds at startup. Other hosts read history directly as described
above; if the user asks for capture there, use that host's supported
mechanism and keep raw staging local and out of version control.
