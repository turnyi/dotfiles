---
name: fork-pane
description: Clone this conversation into a new tmux pane so it continues in parallel. Use when the user says fork, clone, branch this conversation, split off, or asks for a second Claude in a vertical/horizontal split or new window.
---

# Fork this conversation into a tmux pane

Run the script and report the result. Nothing else — do not summarize context,
do not write handoff notes, do not ask what the fork should work on unless the
user's request is genuinely ambiguous about the layout.

```bash
~/scripts/claude-fork-pane.sh <layout> [initial prompt]
```

`<layout>` is one of:

| word | what you get |
| --- | --- |
| `vertical` | side-by-side split (default) |
| `horizontal` | stacked top/bottom split |
| `window` | a new tmux window |

Pick the layout from the user's words: "vertical", "side by side", "next to
this" → `vertical`; "horizontal", "below", "underneath" → `horizontal`; "new
window", "new tab" → `window`. With no hint, use `vertical`.

Anything the user wants the fork to start working on goes after the layout as
a single quoted argument, e.g.:

```bash
~/scripts/claude-fork-pane.sh horizontal "investigate the failing auth test"
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

One line: the layout used and, when given, what the fork was told to work on.
The pane is already visible to the user — do not describe it further.
