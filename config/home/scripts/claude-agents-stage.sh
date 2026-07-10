#!/usr/bin/env bash
# Right-hand "stage" pane of the agents mission-control window.
#   * idle   -> live read-only preview of the highlighted agent (id in SEL file)
#   * docked -> this placeholder has been swapped into the docked agent's home
#               window, so it shows a "docked" banner there instead.
# Usage: claude-agents-stage.sh <stage_pane_id>
set -u
stage="${1:-}"
[ -n "$stage" ] || exit 0
SEL="${TMPDIR:-/tmp}/claude-agents-sel.$stage"
DOCK="${TMPDIR:-/tmp}/claude-agents-dock.$stage"

printf '\033[?25l'                       # hide cursor
trap 'printf "\033[?25h\033[?1049l"' EXIT INT TERM

while :; do
  docked="$(cat "$DOCK" 2>/dev/null)"
  if [ -n "$docked" ]; then
    title="$(tmux display -p -t "$docked" '#{pane_title}' 2>/dev/null)"
    printf '\033[H\033[2J'
    printf '\033[1;33m  ⇦ docked in the agents dashboard\033[0m\n\n'
    printf '     \033[1m%s\033[0m\n\n' "$title"
    printf '\033[2m     Interact with it over there.\n     Ctrl-u in the list sends it back here.\033[0m\n'
    sleep 0.6
    continue
  fi
  id="$(cat "$SEL" 2>/dev/null)"
  if [ -n "$id" ] && tmux display -p -t "$id" '#{pane_id}' >/dev/null 2>&1; then
    title="$(tmux display -p -t "$id" '#{pane_title}' 2>/dev/null)"
    body="$(tmux capture-pane -ep -t "$id" 2>/dev/null)"
    printf '\033[H\033[2m preview · %s · Enter = interact here\033[0m\033[K\n' "$title"
    printf '%s\033[J' "$body"
  else
    printf '\033[H\033[2J\033[2m  Highlight an agent on the left.\n  Enter = interact with it here · Ctrl-u = release\033[0m'
  fi
  sleep 0.6
done
