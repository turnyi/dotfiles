#!/usr/bin/env bash
# claude-attention.sh — status-right segment counting Claude panes that want you.
#
# The per-window tab glyph from claude-window-status.sh only tells you about the
# window it is drawn on, so an agent asking a question in another window goes
# unseen. This segment is global: it renders in status-right from every window.
#
# Prints nothing at all when no agent is waiting, so the bar stays quiet.
set -u

asking=0
blocked=0

while read -r state; do
  case "$state" in
    asking)  asking=$((asking + 1)) ;;
    blocked) blocked=$((blocked + 1)) ;;
  esac
done < <(tmux list-panes -a -F '#{@claude_state}' 2>/dev/null)

[ "$asking" -eq 0 ] && [ "$blocked" -eq 0 ] && exit 0

out=""
[ "$blocked" -gt 0 ] && out="#[fg=#f38ba8,bold]! $blocked#[fg=default,nobold]"
if [ "$asking" -gt 0 ]; then
  [ -n "$out" ] && out="$out "
  out="$out#[fg=#cba6f7,bold]? $asking#[fg=default,nobold]"
fi

printf '%s ' "$out"
