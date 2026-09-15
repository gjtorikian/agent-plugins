# interactive-explainer

Builds a single offline HTML page that explains a real codebase bug, fix, data shape, or design decision through interactions that reveal behavior: a before/after toggle, tabs, a path simulator, clickable data bars, or a rendered fixture row. Every claim is grounded in the repository and cites a real `file:line` location. The page is inline HTML, CSS, and JavaScript with no runtime dependencies, so it opens straight from disk with no server or network. It is written to an ignored scratch path such as `tmp/explainer-<topic>.html` after the skill confirms git actually ignores it, and it is never committed unless you ask.

| Skill                   | Claude Code                                    | Codex                    | Pi                             |
| ----------------------- | ---------------------------------------------- | ------------------------ | ------------------------------ |
| `interactive-explainer` | `/interactive-explainer:interactive-explainer` | `$interactive-explainer` | `/skill:interactive-explainer` |

Install it alongside the other plugins in this marketplace:

```text
/plugin install interactive-explainer@gjtorikian-plugins
```

```sh
codex plugin add interactive-explainer@gjtorikian-plugins
```

Adapted from minimul's [interactive-explainer](https://github.com/minimul/minimul-skills/blob/2d31a38de7dbb81a83554d765161337e2ff6db07/interactive-explainer/SKILL.md) at commit `2d31a38de7dbb81a83554d765161337e2ff6db07`. The port keeps the offline output, source-grounded explanations, dark styling, and interactive controls. It drops host-only frontmatter and named tool dependencies, verifies the scratch directory's ignore rule, and falls back to inspecting the HTML when no browser is available.
