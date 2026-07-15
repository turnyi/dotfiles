#!/usr/bin/env bash
# claude-window-status.sh <window_id>
# Emit a compact status marker for the Claude Code agent(s) in a tmux window,
# for display in the window tab (wired into @catppuccin_window_text in .tmux.conf
# so you can see, at a glance across the tabs, which windows have an agent that
# is working vs. one that is waiting on you).
#
# Claude Code sets each pane's title to "<glyph> <summary>", where the leading
# glyph is a Braille spinner (U+2800-U+28FF, UTF-8 e2 a0..a3) while it is WORKING
# and "✳" once it is IDLE / waiting for input. We scan every pane in the window
# and print one colour-tagged glyph PER claude agent, in pane order:
#   ● cyan   that agent is working
#   ✓ green  that agent is idle / waiting for you
# e.g. a window with three agents (one working, two waiting) => "● ✓ ✓".
# Nothing is printed for windows with no claude agent, so ordinary windows keep
# their plain folder-name tab. Colours use tmux #[...] style tags; the markers
# are appended after the folder name, so the trailing #[default] reset is safe.
set -u

win="${1:-}"
[ -n "$win" ] || exit 0

while IFS=$'\t' read -r cmd title; do
  [ "$cmd" = claude ] || continue
  hex="$(printf '%s' "$title" | head -c3 | xxd -p 2>/dev/null)"
  case "$hex" in
    e2a0* | e2a1* | e2a2* | e2a3*) printf ' #[fg=cyan]●#[fg=default]' ;;
    *)                             printf ' #[fg=green]✓#[fg=default]' ;;
  esac
done < <(tmux list-panes -t "$win" -F $'#{pane_current_command}\t#{pane_title}' 2>/dev/null)
