# intent-log

Keep one global daily log of what a person asked for, why they wanted it, and
which pull requests resulted, across every repository they touch. The shared
[skill](skills/intent-log/SKILL.md) works in Codex, Claude Code, and Pi.

## Use

Install `intent-log` through the repository's
[host installation instructions](../../README.md), then ask:

> Update my intent log from this conversation and verify the linked PRs.

| Host | Explicit invocation |
| --- | --- |
| Codex | `$intent-log` |
| Claude Code | `/intent-log:intent-log` |
| Pi | `/skill:intent-log` |

The log lives at `~/.intent-log/intent-log.md`, outside any repository;
`INTENT_LOG_HOME` overrides the directory. Every PR tag names its repository,
such as `` `owner/repo#26` ``, because one log spans them all. The log is one
person's: it never merges teammates' entries. Backfills need actual human
prompts or supplied history; a diff alone does not establish intent.

## Pi extension: automatic capture

Pi users get prompt capture with the same package. The bundled
[extension](extensions/intent-log/index.ts) records each prompt you type, and
once the agent run it started has ended, appends it to
`~/.intent-log/staging/<local date>.jsonl` with the timestamp, working
directory, `owner/repo`, branch, and session. Host commands such as `/model`
and shell escapes are skipped; `/skill:...` invocations are kept as typed.
At startup, an interactive session is told how many prompts are waiting:

> intent-log: 14 prompts from 3 days staged in ~/.intent-log/staging (oldest
> 2026-09-12). Run /skill:intent-log to write them up.

The extension never calls a model and never edits the log. Writing entries is
still the skill's job: it reads staging first, then moves each written-up day
into `~/.intent-log/staging/logged/`, which the reminder ignores. Staging
holds raw prompts, so keep it out of version control.

The extension loads with the package after `pi update`, or try it in one
session first:

```sh
pi -e /path/to/agent-plugins/plugins/intent-log/extensions/intent-log/index.ts
```

To keep the skill but drop capture, disable the extension with `pi config`,
or filter it in `settings.json` package options with `"extensions": []`.
Claude Code and Codex have no capture in this plugin; the skill reads their
history directly.

## Helper

Ruby 2.7+ and its standard library are needed for the bundled checker. Live PR
verification uses authenticated `gh search prs`; a repository connector can
instead supply a verified JSON snapshot. No gems, session extractor, or
background hooks are required. The checker reads the default log path, so it
runs from any directory. Replace `<skill-dir>` with the installed
`skills/intent-log` path:

```sh
ruby "<skill-dir>/scripts/check.rb"
ruby "<skill-dir>/scripts/check.rb" --owner myorg
ruby "<skill-dir>/scripts/check.rb" --prs-json /path/to/prs.json
```

See [verification](skills/intent-log/references/verification.md) for scope,
custom paths, and offline evidence. Without Ruby, the agent can apply the
documented checks manually and report that limitation.

## Source and portability

Adapted from Irina Nazarova's
[intent-log](https://github.com/irinanazarova/intent-log/tree/04be86a0056282ab8ee7bdc67fbf6720983fd679/skills/intent-log),
at commit `04be86a0056282ab8ee7bdc67fbf6720983fd679`, including `check.rb`.

The port preserves concise daily entries, evidence-backed human decisions,
verified PR tags, and work-block dating. It departs from upstream in scope:
the log is global to one person rather than kept per repository, so PR tags
carry an `owner/repo` prefix, verification uses `gh search prs --author`
scoped to the log's first entry instead of `gh pr list`, and the per-person
team composer is not included. History collection reads the staging files the
Pi extension writes, then whatever conversation or local transcripts the host
makes available; that extension stands in for the upstream Claude-specific
extractor, capture hook, and reminder hook, which are not included.

The checker adds JSON evidence input, `--owner` and `--since` scoping, refuses
potentially truncated live results, and invokes subprocesses without shell
interpolation so installed paths with spaces work. Both plugin adapters share
`./skills/`; the existing Pi glob discovers that same content.
