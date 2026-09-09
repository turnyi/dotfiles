---
name: fork-pane
description: Clone this conversation into a new tmux pane so it continues in parallel. Use when the user says fork, clone, branch this conversation, split off, or asks for a second Claude to the right/left/above/below or in a new window.
---

# Fork this conversation into a tmux pane

Run the script and report the result. Nothing else — do not summarize context,
do not write handoff notes, do not ask what the fork should work on unless the
user's request is genuinely ambiguous about where the pane goes.

```bash
~/scripts/claude-fork-pane.sh <direction> [initial prompt]
```

`<direction>` is one of:

| word | where the fork opens |
| --- | --- |
| `right` | to the right of this pane (default) |
| `left` | to the left of this pane |
| `bottom` | below this pane |
| `top` | above this pane |
| `window` | a new tmux window |

Pick the direction from the user's words: "right", "side by side", "next to
this" → `right`; "left" → `left`; "bottom", "below", "underneath", "down" →
`bottom`; "top", "above", "up" → `top`; "new window", "new tab" → `window`.
With no hint, use `right`.

Anything the user wants the fork to start working on goes after the direction
as a single quoted argument, e.g.:

```bash
~/scripts/claude-fork-pane.sh bottom "investigate the failing auth test"
```

## What the fork gets

`--fork-session` copies the transcript under a new session id, so the new pane
starts with everything said so far and both sides diverge from there — neither
overwrites the other's history.

The copy is made from the transcript on disk, so the fork will not see the
turn currently in flight (the message that triggered this skill, and your reply
to it). If the user just told you something the fork needs, pass it as the
initial prompt.

## Reporting back

One line: the direction used and, when given, what the fork was told to work
on. The pane is already visible to the user — do not describe it further.
