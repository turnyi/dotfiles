#!/usr/bin/env bash
# Right-hand "stage" pane of the agents mission-control window: a live read-only
# preview that follows the highlighted agent in the list (id in the SEL file).
# Pinned agents (tab) become their own real tiles alongside this preview.
# Usage: claude-agents-stage.sh <stage_pane_id>
set -u
stage="${1:-}"
[ -n "$stage" ] || exit 0
SEL="${TMPDIR:-/tmp}/claude-agents-sel.$stage"

printf '\033[?25l'                       # hide cursor
trap 'printf "\033[?25h\033[?1049l"' EXIT INT TERM

while :; do
  id="$(cat "$SEL" 2>/dev/null)"
  if [ -n "$id" ] && tmux display -p -t "$id" '#{pane_id}' >/dev/null 2>&1; then
    title="$(tmux display -p -t "$id" '#{pane_title}' 2>/dev/null)"
    body="$(tmux capture-pane -ep -t "$id" 2>/dev/null)"
    printf '\033[H\033[2m preview · %s · enter = go · tab = pin\033[0m\033[K\n' "$title"
    printf '%s\033[J' "$body"
  else
    printf '\033[H\033[2J\033[2m  Highlight an agent on the left.\n  enter = go to it · tab = pin it as a tile\033[0m'
  fi
  sleep 0.25
done
