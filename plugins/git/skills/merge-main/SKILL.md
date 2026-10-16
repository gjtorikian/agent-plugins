---
name: merge-main
description: Merges the repository's default branch (main, master, production, or whatever it is called) into the current branch, resolves any merge conflicts by combining both sides' intent, and verifies the result builds before committing the merge. Use when the user asks to merge main, update or sync a branch with main, catch a branch up, bring in upstream changes, or resolve merge conflicts. Never rebases, never force-pushes, and pushes only when `--push` is passed.
---

# Merge Default Branch

You bring the current branch up to date with the repository's default branch by merging, then resolve whatever conflicts that produces. The user has delegated the tedious part: finding out what the default branch is actually called, fetching it, working through each conflicted file with both sides' intent in mind, and confirming the merged result still builds. Act autonomously within the rails below. Conflict resolution embeds intent decisions, so when two sides genuinely disagree and the history does not settle it, ask one focused question rather than guessing.

Before resolving any conflict, read [references/conflict-resolution.md](references/conflict-resolution.md) relative to this skill. It covers how to read a three-way conflict, per-file-type rules (lockfiles, generated files, changelogs, deletions, binaries), and semantic conflicts that produce no markers.

## Arguments

Parse any arguments included with the invocation or request:

- **Branch name** (e.g., `develop`): merge this branch instead of the detected default branch.
- `--remote <name>`: the remote to fetch from (default `origin`). Useful for forks where the default branch lives on `upstream`.
- `--push`: push the current branch after a successful merge. Without it, never push.
- `--no-check`: skip the build and test verification after the merge.

## Step 1: Detect the default branch

Unless a branch was given, determine the default branch name in this order and record which method succeeded:

1. `git symbolic-ref --short refs/remotes/<remote>/HEAD` (e.g., `origin/main`). If it is unset, `git remote set-head <remote> --auto` and try again.
2. `gh repo view --json defaultBranchRef --jq .defaultBranchRef.name`, when the GitHub CLI is available and authenticated.
3. `git remote show <remote>` and read the `HEAD branch:` line.
4. The first of `main`, `master`, `trunk`, `develop` that exists under `refs/remotes/<remote>/`.

If none of these yields a branch, stop and ask. Always merge the remote-tracking ref (`<remote>/<branch>`), never the local copy, which may be stale.

## Step 2: Preflight

1. Confirm the repository is not mid-operation: `git status` must not report a merge, rebase, cherry-pick, or revert in progress. If one is, stop and ask; do not abort someone else's operation.
2. If the current branch is the default branch, stop. There is nothing to merge in; suggest `git pull`.
3. If the worktree has uncommitted changes (`git status --porcelain`), stop and ask whether to commit them first (the `commit` skill, `git:commit`, does that) or set them aside. Never stash, reset, or discard changes on your own.
4. Fetch: `git fetch <remote> <branch>`.
5. Already up to date? `git merge-base --is-ancestor <remote>/<branch> HEAD`. If it succeeds, report that and stop.
6. Preview what is coming:
   - commit count: `git rev-list --count HEAD..<remote>/<branch>`
   - files: `git diff --stat HEAD...<remote>/<branch>`
   - predicted conflicts without touching the worktree: `git merge-tree --write-tree --name-only HEAD <remote>/<branch>` (Git 2.38 or newer; if unsupported, skip this and find out from the merge itself).

Tell the user in one line what you are about to merge: the branch, how it was detected, how many commits, and how many files are expected to conflict.

Record progress with the host's task-tracking feature when available: one item per conflicted file, updated as each is resolved.

## Step 3: Merge

```
git merge --no-edit <remote>/<branch>
```

Let Git choose fast-forward or a merge commit; do not force either. If the merge completes cleanly, go to Step 5.

If Git reports conflicts, list them with `git diff --name-only --diff-filter=U` and continue to Step 4. Do not run `git merge --abort` unless resolution turns out to be impossible or the user asks; if you do abort, say so explicitly.

## Step 4: Resolve each conflict

For every conflicted file, understand both sides before editing anything:

1. **What each side intended.** Commit messages carry intent:
   - this branch: `git log --oneline <merge-base>..HEAD -- <file>`
   - the default branch: `git log --oneline <merge-base>..<remote>/<branch> -- <file>`
   - where `<merge-base>` is `git merge-base HEAD <remote>/<branch>`.
2. **The three versions.** `git show :1:<file>` is the common ancestor, `:2:` is this branch (ours), `:3:` is the default branch (theirs). For a text file, re-materialize the conflict with the ancestor visible: `git checkout --conflict=diff3 -- <file>`. Seeing the base makes it obvious which side changed what.
3. **Resolve by category** using the reference: hand-merge source files so both intents survive; regenerate lockfiles and generated output from the merged sources instead of editing them; keep both changelog entries; follow renames and deliberate deletions; pick a side for binaries and flag it.
4. **Verify the file** has no markers left: `git diff --check` and `grep -nE '^(<{7}|={7}|>{7})' <file>` should both be clean. Then `git add <file>`.
5. **When the two sides genuinely disagree** and neither the history nor the surrounding code settles which intent wins, resolve every other file first, then ask the user one question that summarizes both versions in a sentence each. Do not pick a side silently.

Only touch conflicted files, plus the lockfiles and generated outputs you regenerate from them. Do not fix unrelated problems you notice along the way; mention them in the report instead.

## Step 5: Verify the merged tree

Unless `--no-check` was passed, confirm the merged tree works before committing. Pick the fastest relevant checks the repository offers:

- `package.json` scripts: `typecheck`, `lint`, `build`, `test` (in that order of cost); use the repo's package manager, detected from the lockfile.
- Ruby: `bundle exec rubocop` and `bundle exec rspec` or `bundle exec rake test`.
- Rust: `cargo check` then `cargo test`.
- Go: `go build ./...` then `go test ./...`.
- Python: `ruff` or `flake8`, then `pytest`.
- A `Makefile` or `justfile` with obvious `check`, `lint`, or `test` targets.

Prefer a typecheck or build over a full test suite when the suite takes more than a few minutes; at minimum run the tests that cover the files you resolved. Semantic conflicts (a function renamed on one side and called on the other) produce no markers and only show up here, so treat a failure as part of the resolution and fix it. If a failure is clearly unrelated to the merge, confirm it also fails on `<remote>/<branch>` before concluding that, report it, and do not block the merge on it.

## Step 6: Commit the merge

If the merge fast-forwarded or Git already committed it, there is nothing to do. Otherwise:

```
git commit --no-edit
```

Keep Git's generated merge message. Never pass `--no-verify`; if a commit hook rejects the merge, show its output and ask how to proceed.

## Step 7: Push

Only when `--push` was passed:

1. `git push`.
2. If the branch has no upstream, `git push -u <remote> HEAD`.
3. If the push is rejected because the remote branch has commits you do not have, surface the error and stop. Do not force-push and do not pull automatically.

## Report

Always end with a report, whatever the exit reason:

```
## Merge report: <remote>/<branch> → <current branch>

- **Default branch:** <name> (detected via <method>)
- **Merged:** <N> commits, <M> files changed
- **Conflicts:** <count>
  - `<file>`: <how it was resolved, one line>
- **Checks:** <what ran and the result, or "skipped (--no-check)">
- **Pushed:** <yes | no>
- **Needs you:** <judgment calls you flagged, pre-existing failures, anything deliberately left alone; or "nothing">
```

## Rails

- Merge only. Never rebase, reset, amend, or rewrite history on the branch.
- Never resolve the whole merge with `-X ours` or `-X theirs`, and never take a whole file with `--ours` or `--theirs` without reading both sides first. Lockfiles and generated files follow the reference's regeneration rules instead.
- Never stash, discard, or overwrite the user's uncommitted work.
- Never force-push, and never push at all without `--push`.
- Never bypass hooks.
