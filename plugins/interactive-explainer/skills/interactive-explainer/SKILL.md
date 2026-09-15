---
name: interactive-explainer
description: Build a self-contained, offline interactive HTML page explaining a codebase bug, fix, data shape, design decision, or GitHub PR. PR inputs also receive a code review in a separate page section. Use when the user asks to make an interactive HTML, build an interactive explainer, or visualize a bug or fix.
---

# Interactive Explainer

Create one HTML file that lets the reader explore how the actual code behaves.

## Requirements

- Keep everything in one `.html` file with inline styles and scripts. It must
  work when opened directly from disk, without a server, network requests,
  CDNs, Mermaid, external fonts, or other dependencies.
- Ground explanations in the repository. Read the relevant code, schema,
  fixtures, and tests before writing. Cite real repository-relative `file:line`
  locations beside the claims they support. Use verified column names, types,
  counts, and before/after code; label anything that cannot be verified.
- Use the system theme (`prefers-color-scheme`). Prefer locally installed
  Helvetica Neue with `font-family: "Helvetica Neue", Helvetica, Inter, Arial, system-ui, sans-serif;`.
  Use system monospace fonts for code; do not download fonts.
- Keep labels free of emoji and literal Unicode arrows; use words or HTML
  entities such as `&rarr;`.
- Include a meaningful interaction that reveals behavior or a consequence.
  A static document with decorative buttons does not satisfy this workflow.

## Workflow

1. Identify the bug, fix, data structure, or decision from the invocation and
   conversation. Find its real source in the project using the available file,
   search, and command capabilities. If the input identifies a GitHub PR by URL
   or number in repository context, also follow [PR review](#pr-review) below.
2. Collect the concrete inputs, outputs, schema details, and source locations
   needed to explain it. Distinguish current behavior from a proposed fix.
   Use existing safe fixtures where possible; do not embed credentials or
   private production records in a shareable page.
3. Choose interactions that fit the explanation; combine only useful ones:
   - **Before/after toggle:** compare the broken and corrected flow, rows, or UI.
   - **Tabs:** separate concerns such as the bug, data, fix, and tests.
   - **Path simulator:** select a scenario and inspect the resulting state.
   - **Clickable data bars:** reveal the source and meaning of each metric.
   - **UI or database-row view:** render actual fixture shapes through the
     relevant view logic and highlight the cells involved in the bug.
4. Write `tmp/explainer-<topic>.html` under the project root, unless the user
   specified another destination. Check that the scratch path is ignored by
   git; do not assume every project's `tmp/` is ignored. If necessary, use an
   existing ignored scratch directory or an OS temporary directory and report
   that location. Avoid overwriting an unrelated artifact.
5. When browser capabilities are available, open the local file and exercise
   its controls. Check that each interaction changes the expected state and
   that the page works offline. Otherwise inspect the HTML and JavaScript for
   external dependencies and report that browser verification was unavailable.
6. Return a link to the artifact and its absolute `file://` URL for opening in
   a browser, plus a sentence describing what the reader can explore.

## PR review

For PR inputs, read and follow the GitHub plugin's
[`review` skill](../../../github/skills/review/SKILL.md) for the same PR revision
used by the explainer. When plugins are installed separately, use the installed
GitHub `review` skill (`github:review`) rather than assuming the sibling path
exists. If it cannot be loaded, stop and ask for the GitHub plugin instead of
silently skipping the review.

Reuse that skill's context gathering, analysis, and report structure; do not
substitute a summary of the PR description for a review. Render the report as
HTML in its own **PR review** section, separate from the behavior walkthrough.
Include the overview, severity-ordered findings with `file:line` evidence and
suggested fixes, summary counts, recommended action, verdict, and suggested
reply or submitter actions. Explicitly state when there are no findings and
which checks could not be run. Adapt the review's presentation step to the page:
do not print a second full report in chat or post anything to GitHub.

Keep the output as a scratch artifact unless the user asks to commit or publish
it. Creating the explainer does not imply either action.
