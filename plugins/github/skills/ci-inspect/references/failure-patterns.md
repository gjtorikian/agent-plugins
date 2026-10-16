# CI Failure Patterns

Signatures to look for in logs, what each usually means, and what evidence settles the classification. Classifications: **branch-related**, **base-branch breakage**, **environment**, **configuration**, **flaky**.

## Evidence standard

- **Branch-related** needs: the error points at code, config, or a test the branch touched, or the same workflow is green on the base branch at a comparable time.
- **Base-branch breakage** needs: the same workflow red on the base branch with the same error, ideally with the first red base commit named.
- **Environment** needs: an error from infrastructure (network, runner, registry, GitHub) rather than from the project's own code or tooling.
- **Configuration** needs: an error that persists across attempts and is explained by a workflow, action version, lockfile, cache, secret, or permission issue rather than by the diff.
- **Flaky** needs: the same SHA passing on another attempt, or a documented non-deterministic pattern (timing, ordering, ports, shared state). Without that, classify as uncertain and say what would settle it.

## Dependency installation

Signatures: `npm ERR! code E404`, `ERESOLVE`, `npm ci can only install packages when your package.json and package-lock.json are in sync`, `Could not find gem`, `Bundler could not find compatible versions`, `No matching distribution found`, `error: failed to select a version`, `go: module ... not found`, `ETIMEDOUT`, `ECONNRESET`, `503 Service Unavailable`, `429 Too Many Requests`.

- Lockfile out of sync with the manifest: **configuration** or **branch-related** depending on whether the PR touched the manifest or lockfile. Fix: regenerate the lockfile.
- A version that no longer resolves, with no diff to dependencies: **configuration** (a yanked or removed release) or **base-branch breakage** if the base is red too.
- Timeouts, resets, 5xx, 429 from a registry or mirror: **environment**. Confirm by checking that an earlier or later attempt installed fine.

## Compile, typecheck, and lint

Signatures: `error TS`, `error[E`, `SyntaxError`, `cannot find module`, `undefined method`, `rubocop`/`eslint`/`clippy` violation lists with file and line.

- The reported file or symbol is in the diff: **branch-related** (high confidence).
- The reported file is untouched: check whether the branch changed a shared type, export, or fixture that file depends on (still **branch-related**), then whether a tool version is unpinned and moved (**configuration**), then whether the base is red (**base-branch breakage**).
- Lint failures that only appear on one OS or shell are usually line endings or path separators: **branch-related** if the branch added the file.

## Test failures

Signatures: `FAIL`, `✕`, `AssertionError`, `expected ... got ...`, `Failures:`, `1 example, 1 failure`, `--- FAIL:`, snapshot diffs.

- Same test fails every attempt and lives in or exercises changed code: **branch-related**.
- Snapshot mismatch and the branch changed rendered output or text: **branch-related**; the fix is updating the snapshot if the new output is intended.
- Failures mentioning `Timeout`, `timed out`, `EADDRINUSE`, `ECONNREFUSED` to a service container, `deadlock`, flaky ordering (`random seed`, `--seed`), or clock and timezone sensitivity: candidates for **flaky**, but only call them flaky with a passing attempt on the same SHA or a visible nondeterministic dependency. Otherwise report as uncertain with the seed or timing detail.
- Passes locally, fails in CI: look for `CI=true` behavior, missing environment variables or secrets, locale and timezone, parallel sharding, and tool version differences. Usually **configuration**.
- Many unrelated tests failing at once usually means a shared setup step broke (database, fixtures, a global). Find the first failure, not the loudest.

## Timeouts and cancellations

Signatures: `The job running on runner ... has exceeded the maximum execution time`, `The operation was canceled`, `##[error]The runner has received a shutdown signal`, `Canceling since a higher priority waiting request ... exists`.

- Canceled because a newer push superseded the run under a `concurrency` group: not a failure. Investigate the newest run instead.
- Hit `timeout-minutes`: find what was running when the clock ran out. A hung test or a step waiting on input is **branch-related** if the branch introduced it; a job that always ran close to the limit is **configuration**.
- Runner shutdown or lost communication: **environment**.

## Runner and infrastructure

Signatures: `No space left on device`, `Killed`, exit code `137` (out of memory), `lost communication with the server`, `runner has been terminated`, image provisioning errors, `Resource temporarily unavailable`.

Usually **environment**. Exceptions: disk or memory exhaustion that started with the branch (a huge new fixture, an unbounded test) is **branch-related**. Check the GitHub status page for incidents around the run's timestamp when several unrelated jobs died together.

## Permissions and secrets

Signatures: `Resource not accessible by integration`, `HttpError: 403`, `Bad credentials`, `Input required and not supplied`, empty secret values, `permission denied` on a push or release step.

- The run is a `pull_request` event from a fork (`isCrossRepository` true): secrets are not available by design. **Configuration**, and the fix is usually that the step should be skipped on fork PRs or moved to `pull_request_target` with care.
- `GITHUB_TOKEN` lacks a scope: the workflow or job needs a `permissions:` block. **Configuration**.
- A secret was rotated or expired: **configuration**; the base branch will be red too.

## Action and tool version drift

Signatures: `Node.js 16 actions are deprecated`, `This request has been automatically failed because it uses a deprecated version of actions/...`, `set-output` or `save-state` deprecation turned error, `ubuntu-latest` behavior changes, `@latest` or `@v1` references, a tool printing a new major version in its banner.

Usually **configuration**, and usually **base-branch breakage** at the same time since it affects every branch from a date onward. Evidence: the first red base run with no relevant diff. Fix: pin the action or tool to a known-good version, or upgrade it.

## Cache

Signatures: `Cache not found for input keys`, `Failed to restore`, `Failed to save`, a step succeeding but using stale artifacts (old compiled output, old dependency versions).

- Cache miss alone is not a failure; look for what actually failed afterward.
- A restored cache that no longer matches the lockfile or toolchain: **configuration**; fix the cache key so it includes the lockfile hash or tool version.
- Cache service errors (`Cache service responded with 503`): **environment**.

## Artifacts between jobs

Signatures: `Artifact not found`, `Unable to find any artifacts for the associated workflow`, `No files were found with the provided path`.

The failing job is downstream of the real failure. Find the job that was supposed to upload the artifact; it either failed, was skipped by an `if:` condition, or uploaded under a different name or path. Classify the upstream cause, not this one.

## Containers and services

Signatures: `pull access denied`, `manifest unknown`, `toomanyrequests: You have reached your pull rate limit`, service container health check failures, `connection refused` to `localhost:<port>` early in a job.

- Registry rate limits and pull failures: **environment** unless the branch changed the image reference.
- A service container that never became healthy: **configuration** if the health check or port mapping changed, **environment** if it usually works.
- Connection refused early in the job: the test started before the service was ready. Often **flaky** with evidence of passing attempts, otherwise **configuration** (missing wait or health check).

## Matrix-specific failures

A failure on one OS or language version only. Typical causes: path separators and case-sensitive filesystems, platform-specific dependencies, syntax or standard library features unavailable in the oldest version, shell differences on Windows. Almost always **branch-related** when the branch added the affected code, or **configuration** when the matrix recently gained a new entry.

## Workflow file errors

Signatures: run fails before any job starts, `Invalid workflow file`, `Unexpected value`, `The workflow is not valid`, a job with no steps executed.

**Branch-related** if the PR changed the workflow file; otherwise **base-branch breakage**. Read the YAML at the exact ref and quote the offending line.

## Telling branch-related from base breakage quickly

| Base branch recent runs | Branch runs | Likely classification |
| --- | --- | --- |
| Green | Red with this push | Branch-related |
| Green | Red since an earlier push | Branch-related; name that push |
| Red with the same error | Red | Base-branch breakage |
| Red with a different error | Red | Two problems; report both |
| Mixed, same SHA | Mixed | Flaky, with the attempt evidence |
