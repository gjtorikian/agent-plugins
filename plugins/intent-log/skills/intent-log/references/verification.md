# Checking an intent log

The checker requires Ruby 2.7+ with no gems. It reads
`~/.intent-log/intent-log.md`, or `intent-log.md` under `INTENT_LOG_HOME`, so
it runs from any directory. Resolve `<skill-dir>` relative to the installed
skill. A positional path checks a log somewhere else.

```sh
ruby "<skill-dir>/scripts/check.rb"
ruby "<skill-dir>/scripts/check.rb" /path/to/intent-log.md
```

## Live PR evidence and its scope

By default, the checker runs authenticated `gh search prs --author @me` for
every PR the person created on or after the date of the log's first entry,
in every repository, capped at 500 results. Each PR must appear in exactly one
tag with the right marker, and every tag must name a PR in that result.

- If the cap is reached, the checker refuses to treat the result as complete.
  Increase `--limit N` (GitHub search stops at 1000), narrow the scope, or
  provide an explicit snapshot.
- `--owner OWNER`, repeatable, limits coverage to repositories under those
  owners. Use it when the person opens drive-by PRs in projects they do not
  journal. Report the narrowed scope.
- `--since DATE` moves the coverage start. Use it when the log deliberately
  begins after the person's PR history does. A tag for a PR created before
  the scope start is reported as outside the evidence; widen `--since` or
  supply a snapshot that includes it.
- `--author LOGIN` fetches another person's PRs. It exists for checking a log
  someone handed over, not for writing entries on their behalf.

The checker does not call an agent host or read conversation history, and it
does not verify that a human made a decision.

```sh
ruby "<skill-dir>/scripts/check.rb" --owner myorg --owner mylogin
ruby "<skill-dir>/scripts/check.rb" --since 2026-09-01 --limit 1000
```

## Offline or scoped PR evidence

An available repository connector can provide the same evidence without `gh`.
Write its verified results to a local JSON array and pass `--prs-json PATH`.
Each record names its repository as `owner/name`, or as an object with
`nameWithOwner` in the shape `gh` emits. States are `open`, `closed`, or
`merged`, in either case.

```json
[
  {"repository": "sam/party", "number": 26, "state": "merged", "title": "Pixel invitations"},
  {"repository": "sam/party", "number": 61, "state": "open", "title": "Repair preview"},
  {"repository": {"nameWithOwner": "sam/tools"}, "number": 7, "state": "closed", "title": "Automatic welcome"}
]
```

```sh
ruby "<skill-dir>/scripts/check.rb" --prs-json /absolute/path/prs.json
```

This validates against the supplied snapshot, not current live state or an
independently complete history. Report the snapshot's time and scope. For a
partial log, include every PR in the agreed owner/date scope **and every PR
already tagged anywhere in that log**. Do not build the snapshot from logged
tags alone: that would hide missing entries. An empty array is appropriate
only when verified evidence says the requested scope has no PRs.

If neither live access nor a verified snapshot exists, inspect formatting and
intent manually and report that PR coverage and state remain unverified.

## Rewrapping

`check.rb --fix` only rewraps text; it exits without validating PRs or dates.
Tags stay on one line. Then run the checker without `--fix`:

```sh
ruby "<skill-dir>/scripts/check.rb" --fix
ruby "<skill-dir>/scripts/check.rb"
```

The checker verifies structural rules, not whether a human made a decision.
Review the evidence and diff after it passes. Keep an explicit year in the
first entry and at year changes; `--year` is a fallback for diagnosing legacy
logs, not a replacement for fixing their headings.
