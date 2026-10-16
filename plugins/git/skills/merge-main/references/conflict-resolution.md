# Conflict Resolution Guide

How to read a conflict, how to resolve each kind of file, and the conflicts that leave no markers.

## Reading a three-way conflict

Default markers show only the two tips:

```
<<<<<<< HEAD              (ours: the current branch)
...
=======
...
>>>>>>> origin/main       (theirs: the default branch)
```

Re-materialize with the common ancestor so you can see what each side changed rather than guessing:

```
git checkout --conflict=diff3 -- <file>
```

```
<<<<<<< HEAD
ours
||||||| merged common ancestors
base
=======
theirs
>>>>>>> origin/main
```

Compare each side to the base, not to each other. The side that differs from the base is the one that made a change there; if both differ, both made changes and the resolution must usually keep both. Raw versions are also available: `git show :1:<file>` (base), `:2:` (ours), `:3:` (theirs).

Read the intent before editing: `git log --oneline <merge-base>..HEAD -- <file>` and `git log --oneline <merge-base>..<remote>/<branch> -- <file>`. A commit titled "Remove legacy X" tells you a deletion was deliberate; "Rename X to Y" tells you where a modification should move.

## Source code

- **Both sides changed different things in the same hunk**: keep both. Reorder if one must come first.
- **Both sides changed the same thing**: find out why. The default branch's version usually reflects a decision already reviewed and merged; this branch's version reflects what the user is building. If the branch's change is the whole point of the branch, keep it and adapt it to the default branch's surrounding changes. If the default branch fixed a bug the branch also touched, prefer the fix and re-apply the branch's intent on top. When it is genuinely a coin flip, ask.
- **Imports, requires, declaration lists, enum members, route tables**: keep both sets, remove duplicates, follow the file's existing ordering convention.
- **Function signatures changed on the default branch**: update every caller this branch added to the new signature. Grep for the symbol across the branch's diff, not only in conflicted files.
- **Formatting-only differences** (the default branch ran a formatter): take theirs for the formatting, then re-apply the branch's logical change, and run the formatter on the result if the repo has one.

## Lockfiles

`package-lock.json`, `yarn.lock`, `pnpm-lock.yaml`, `bun.lock`, `Gemfile.lock`, `Cargo.lock`, `poetry.lock`, `uv.lock`, `Pipfile.lock`, `go.sum`, `composer.lock`, `mix.lock`.

Never hand-merge a lockfile. Resolve the manifest first (`package.json`, `Gemfile`, `Cargo.toml`, `pyproject.toml`, `go.mod`), then regenerate the lockfile from it:

| Tool | Regenerate |
| --- | --- |
| npm | `git checkout --theirs package-lock.json && npm install --package-lock-only` |
| yarn | `git checkout --theirs yarn.lock && yarn install --mode=update-lockfile` (Berry) or `yarn install` (classic) |
| pnpm | `git checkout --theirs pnpm-lock.yaml && pnpm install --lockfile-only` |
| bun | `git checkout --theirs bun.lock && bun install` |
| bundler | `git checkout --theirs Gemfile.lock && bundle install` or `bundle lock` |
| cargo | `git checkout --theirs Cargo.lock && cargo update --workspace` (never `cargo generate-lockfile`, which bumps every dependency) |
| poetry / uv | `git checkout --theirs <lock> && poetry lock --no-update` or `uv lock` |
| go | `git checkout --theirs go.sum && go mod tidy` |

Taking theirs first gives the regeneration a consistent starting point; the install step then adds back whatever the branch's manifest needs. Confirm the resulting lockfile diff against the default branch only contains the branch's own dependency changes. If the tool is not installed locally, say so, take theirs, and flag that the lockfile must be regenerated before the branch is merged.

## Generated files

Snapshots, compiled assets, schema dumps (`db/schema.rb`, `structure.sql`, `schema.prisma` migrations output), API clients, OpenAPI or GraphQL schema output, translation catalogs, `*.generated.*`, anything with a `DO NOT EDIT` header.

Take theirs, resolve the source that generates the file, then run the generator. If you cannot run it, take theirs and flag that regeneration is pending. For test snapshots, regenerate by running the snapshot update command for only the affected tests and review that the new output is what the branch intends.

## Changelogs and release notes

Keep both sides' entries. Put each entry under the correct version heading: the default branch's entries usually belong to a released version, this branch's entries to the unreleased section. Preserve the file's ordering convention (newest first, grouped by type).

## Deleted on one side, modified on the other

Git reports `deleted by us` or `deleted by them`.

1. Check whether it was really a rename: `git log --diff-filter=D --oneline <merge-base>..<side> -- <file>` and `git log -M --summary` on that commit. If the file was moved, apply the other side's modification to the new location and `git rm` the old path.
2. If it was a deliberate deletion (the commit message says so, or the code it contained was replaced), drop the modification too and `git rm` the file. Mention this in the report; it is the kind of thing the user may want to know.
3. If this branch added new behavior to a file the default branch removed, that is a design question. Resolve everything else, then ask.

## Added on both sides

`both added` means two independent files with the same path. Compare them; usually one is a copy that should be dropped or they should be merged into one. If both are new and unrelated, one needs a different name.

## Binary files

Images, fonts, archives, compiled artifacts. Git cannot merge them. Decide by intent: if this branch changed the asset on purpose, `git checkout --ours -- <file>`; if the default branch updated a shared asset and this branch only touched it incidentally, `git checkout --theirs -- <file>`. Always name binary choices in the report.

## Submodules

A conflicted submodule pointer means both sides moved it. Pick the newer commit if one contains the other (`git -C <submodule> merge-base --is-ancestor`); otherwise ask.

## Semantic conflicts without markers

These merge cleanly and break at build or test time:

- the default branch renamed, moved, or removed a function, type, constant, route, or config key that this branch references;
- the default branch changed a signature, return type, or default value that this branch's new call sites assume;
- both sides added a migration, a test with the same name, a CSS class, or a database constraint that now collides;
- the default branch changed a lint rule or type strictness that this branch's new code violates.

The verification step exists to catch these. When a check fails after a clean-looking merge, read the error as a merge conflict: find what the default branch changed (`git log -p <merge-base>..<remote>/<branch> -- <path or symbol>`) and adapt the branch's code to it.

## Finishing a file

Before staging, confirm:

- no markers remain (`git diff --check`, and grep for lines starting with `<<<<<<<`, `=======`, or `>>>>>>>`);
- the file parses or compiles if that is cheap to check;
- both sides' intents are present, or the report will say which one was dropped and why.

Then `git add <file>`. Do not `git commit` until every conflicted file is staged and the verification step has run.
