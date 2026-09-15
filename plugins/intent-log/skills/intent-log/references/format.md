# Intent log format

Keep the file header to a short explanation and byline, then start the daily
lists. Formatting conventions belong in the skill, not in the reader's way.

```markdown
# Intent log

What I wanted to change and where the work got to, across every repository.
One short list per day.

By Sam

## Thu Sep 10, 2026

- invitation emails in the pixel design `sam/party#26`
- approve each avatar repair before it changes a card `sam/party#25 open`
  **why:** generated avatars sometimes came back with their legs cut off
  **I decided:** preview and approve each repair before replacing the image
- changed my mind on placement: give everyone a random spot
- dropped the automatic welcome message `sam/party#7 dropped`
- retry flaky uploads in the CLI instead of asking people to rerun `sam/tools#3`

*From review: `sam/party#28`*
*Could use a hand: choosing an accessible color palette for the invitations.*

## Fri Sep 11

- let sponsors preview their banner before publishing
```

This is an illustrative example, not evidence about any real repository.

## Dates

The first dated heading must state its year, such as `## Thu Sep 10, 2026`.
Later headings inherit that year until another explicitly names one. The first
entry in January of a new year must include the new year. Verify weekdays.

Use the date when the work block began. A five-hour idle gap ends a block;
midnight alone does not. Merge blocks beginning on the same local date into
one entry, even when they touched different repositories. Retain an existing
explicit range heading when it describes the work accurately; do not move the
ask to its PR's merge date.

## PR tags and tails

| Tag | Verified PR state |
| --- | --- |
| `` `owner/repo#26` `` | Merged |
| `` `owner/repo#61 open` `` | Open |
| `` `owner/repo#7 dropped` `` | Closed without merging |
| No tag | No PR to attach to the ask |

Every tag names its repository as `owner/repo`, because the log spans
repositories and `#26` alone is ambiguous. The tag is the only repository
context a bullet carries; an ask with no PR names no repository. Each PR
appears once across the dated entries, including tails. Put its tag on the
ask that produced it. Do not repeat it in a reasoning sub-line or a later
day's shipped list. A merged removal still uses a merged tag, with words that
explain the abandonment.

Use tails only when they tell the reader something they can act on:

- `*Dropped: ...*`: an abandoned ask with nothing landed.
- `*Postponed: ...*`: a deliberately parked ask that is still wanted.
- `*From review: ...*`: PRs shown by evidence to originate in review rather
  than a human ask. Apply each PR's normal state marker here too.
- `*Could use a hand: ...*`: unresolved work or a decision needing help.

Do not repeat an entire bullet in a tail. A help line should name the remaining
need. Update or remove a help line once the need is resolved.

## Length and wrapping

Bullets contain at most 20 words, including tags; each day contains at most
400 words, including sub-lines and tails. Wrap at 79 characters. Continuation
lines and reasoning sub-lines hang two spaces under their bullet. Keep a tag
such as `` `owner/repo#61 open` `` together when wrapping.
