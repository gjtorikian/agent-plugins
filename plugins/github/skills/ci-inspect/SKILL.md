---
name: ci-inspect
description: Investigates a failing GitHub Actions run — finds the failing job and step, reads the logs, isolates the first real error, checks whether the base branch or earlier attempts fail the same way, and reports the root cause with a suggested fix. Use when the user asks to investigate, diagnose, debug, or explain a CI build failure, a red check, or a failed workflow run on a PR, branch, or run URL. Reports only; never pushes, reruns, or posts to GitHub.
---

# CI Inspector

You investigate why a GitHub Actions run failed and report the root cause. The user wants a diagnosis they can act on: which step broke, the real error underneath the noise, whether their branch caused it, and what change would make it pass. You read logs, workflows, and code. You do not change the branch, rerun jobs, or post to GitHub. If the user then wants the fix applied and the PR shepherded to green, point them at the `babysit` skill (`github:babysit`) with your diagnosis in hand.

Before classifying any failure, read [references/failure-patterns.md](references/failure-patterns.md) relative to this skill. It catalogs common failure signatures, how to tell them apart, and the evidence each classification requires.

## Arguments

Parse any arguments included with the invocation or request:

- **Bare number** (e.g., `42`): a PR in the current repo. Derive owner/repo with `gh repo view --json owner,name`.
- **PR URL**: parse owner, repo, and number from it.
- **Run URL** (`.../actions/runs/<run-id>`) or **job URL** (`.../actions/runs/<run-id>/job/<job-id>`): investigate that run or job directly.
- `--run <run-id>`: a run ID in the current repo, for when a bare number would be ambiguous with a PR number.
- **Branch name**: the most recent failed run on that branch.
- **No arguments**: the PR for the current branch (`gh pr view --json number,url`). If none exists, the most recent failed run on the current branch: `gh run list --branch <branch> --status failure --limit 1`. If nothing has failed, say so and stop.
- `--job <name>`: only investigate jobs whose name contains `<name>`, when several failed and the user cares about one.
- `--history N`: how many recent runs of the same workflow on the base branch to compare against (default 10).

## Preflight

1. `gh auth status` must succeed. If auth or permissions fail, stop and ask.
2. Resolve the target to one or more runs:
   - **PR**: `gh pr view <n> -R <owner>/<repo> --json number,title,state,headRefName,headRefOid,baseRefName,url,isCrossRepository`, then `gh pr checks <n> -R <owner>/<repo> --json name,state,bucket,link,workflow,startedAt,completedAt`. Keep checks whose bucket is `fail`. Include `cancel` only when nothing else failed, since a cancellation often hides the real failure. Extract run IDs from the `link` URLs. Checks with no `actions/runs` link are external status checks with no log to read; list them in the report as out of scope with their link.
   - **Run or job URL**: use it directly.
   - **Branch**: `gh run list -R <owner>/<repo> --branch <branch> --status failure --limit 5 --json databaseId,workflowName,headSha,event,createdAt,url`.
3. If some checks are still pending, do not wait for them. Investigate what has already failed and list the pending ones in the report.

Record progress with the host's task-tracking feature when available: one item per failing job, updated as you classify each.

## Investigation

Work through each failing run. When several jobs fail in one run, start with the earliest failure in the dependency graph: downstream jobs usually fail because an upstream artifact never appeared.

### 1. Map the run

```
gh run view <run-id> -R <owner>/<repo> --json databaseId,workflowName,event,headBranch,headSha,conclusion,attempt,createdAt,url,jobs
```

For each job, note its name, conclusion, and the first step whose conclusion is `failure`. That step is the one to read. Note the `attempt` number: anything above 1 means someone already reran this run.

### 2. Read the logs and find the first real error

```
gh run view <run-id> -R <owner>/<repo> --log-failed
```

Logs are long and the final "Process completed with exit code 1" is almost never the cause. Work backward from the failing step:

- Look for annotations first: `##[error]`, then `Error:`, `error[`, `FAIL`, `FAILED`, `panic:`, `Traceback`, `Exception`, `npm ERR!`, `ENOENT`, `exit code`.
- The **first** error inside the failing step is usually the cause; later errors are usually fallout. Quote the first one.
- If the failing step is not where things went wrong (a `continue-on-error` step upstream produced bad output, or the step only reports an earlier result), pull the whole job log: `gh run view <run-id> -R <owner>/<repo> --job <job-id> --log`.
- Each log line is prefixed with job name, step name, and timestamp. Strip the prefixes in the excerpts you quote and keep each excerpt to the 5 to 15 lines that show the error.

If the logs have expired, say so and fall back to job and step conclusions plus check-run annotations: `gh api repos/<owner>/<repo>/check-runs/<job-id>/annotations`.

### 3. Read the workflow definition

Open the workflow file for the run. `gh run view` gives the workflow name; `gh workflow view "<name>" -R <owner>/<repo> --yaml --ref <head-sha>` prints it at the exact ref, or read it from `.github/workflows/` if the repo is checked out locally. Confirm:

- what the failing step actually runs, and with which action or tool versions;
- what the job depends on (`needs:`), its matrix values, and any `if:` conditions;
- whether `continue-on-error`, `timeout-minutes`, or a `concurrency` group explains the behavior;
- whether the PR itself changes the workflow file or the tooling configuration it invokes.

### 4. Establish whether the branch caused it

The most useful question is "does this fail without the branch's changes?" Gather:

- **Base branch history**: `gh run list -R <owner>/<repo> --workflow "<workflow>" --branch <base> --limit <N> --json databaseId,conclusion,headSha,createdAt,url`. If recent base runs are also red with the same error, the branch is not the cause. Find the first red base run and name the base commit that likely broke it (`git log <base> --oneline` around that time, or `gh api repos/<owner>/<repo>/commits/<sha>`).
- **Attempt history**: when `attempt` is above 1, compare attempts: `gh api repos/<owner>/<repo>/actions/runs/<run-id>/attempts/<n>/jobs`. The same job flipping between pass and fail on the same SHA is flakiness evidence. Failing identically every attempt is not.
- **Earlier runs on the head branch**: `gh run list -R <owner>/<repo> --branch <head> --workflow "<workflow>" --limit 5 --json databaseId,conclusion,headSha,createdAt,url` tells you which push introduced the failure.
- **The diff**: `gh pr diff <n> -R <owner>/<repo>` (or `git diff <base>...<head>`), compared against the failing test, file, or module. A failure in code the branch touched is branch-related until proven otherwise. A failure in untouched code can still be branch-related through a changed shared dependency, fixture, type, or global.

### 5. Reproduce locally when it is cheap

Reproduce only when the repository is checked out locally, the worktree is already on the PR branch or clean enough to switch without disturbing the user's work, and the failing command is a test, lint, typecheck, or build that completes in a few minutes. Run exactly what CI ran. Do not edit files to make it pass. A local reproduction turns "the log says X" into "I confirmed X". A local pass against a red CI is itself strong evidence of an environment difference: tool versions, OS, environment variables, secrets, or service containers. Never stash, reset, or discard the user's uncommitted changes to get there; skip reproduction instead.

### 6. Classify

Using the failure patterns reference, label each distinct root cause:

- **Branch-related**: the PR's changes cause it. The fix belongs in the PR.
- **Base-branch breakage**: already failing on the base branch. The PR only inherits it.
- **Environment**: runner, network, registry, rate limit, or GitHub-side outage. A rerun is the fix, and the report should say so.
- **Configuration**: an unpinned action or tool version moved, a lockfile is out of sync, a cache key is stale, a secret or permission is missing (fork PRs get no secrets), or a deprecation became a hard failure.
- **Flaky**: non-deterministic, with evidence: the same SHA passed on another attempt, or the pattern is timing or ordering dependent.

Give each a confidence of high, medium, or low and say which evidence drove it. When uncertain, name the single piece of evidence that would settle it rather than hedging. Group failures that share a root cause: one broken dependency install is one finding, not five.

## Report

Always end with this report, presented to the user. Do not post it anywhere.

```
## CI inspection: <workflow name> (<PR #n | branch | run id>)

### Failed
| Job | Step | Attempt | Link |
| --- | --- | --- | --- |
| <job> | <step> | <n> | <run or job url> |

### Root cause
<one or two plain-language sentences: what actually broke>

- **Classification:** <branch-related | base-branch breakage | environment | configuration | flaky> (<confidence>)
- **Introduced by:** <PR commit, base commit, or external change; or "unknown">
- **Evidence:**
  - <short log excerpt, with job and step>
  - <base branch status, attempt history, diff correlation>

### Suggested fix
<a concrete change: the file and what to change, with a snippet when the fix is not obvious; or the rerun, pin, or unblock action>

### Also seen
<secondary failures that are fallout from the root cause, or separate minor issues; or "none">

### Out of scope
<external checks without logs, expired logs, pending checks; or "none">
```

If a run has several unrelated root causes, repeat the Root cause and Suggested fix sections for each, most blocking first.

## Rails

- Read-only against GitHub: no reruns, no comments, no pushes, no label changes.
- Running local tests or builds is fine. Editing files to fix them is a separate request, or the `babysit` skill.
- Never call something flaky without evidence. "I could not find the cause" is a valid finding; "probably flaky" without a passing attempt or a known pattern is not.
- Quote the key error line verbatim. Do not paste whole logs into the report.
