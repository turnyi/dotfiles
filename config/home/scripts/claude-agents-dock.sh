#!/usr/bin/env bash
# Dock a Claude pane into the dashboard "stage" for real interaction, or release
# it. Uses swap-pane, so releasing restores the agent to its exact home slot.
#
#   claude-agents-dock.sh <agent_pane_id> <stage_pane_id>   dock / toggle-focus
#   claude-agents-dock.sh --release <stage_pane_id>         send docked agent home
set -u

exists() { tmux display -p -t "$1" '#{pane_id}' >/dev/null 2>&1; }

if [ "${1:-}" = --release ]; then
  stage="${2:-}"; [ -n "$stage" ] || exit 0
  DOCK="${TMPDIR:-/tmp}/claude-agents-dock.$stage"
  docked="$(cat "$DOCK" 2>/dev/null)"
  [ -n "$docked" ] && exists "$docked" && tmux swap-pane -s "$docked" -t "$stage" 2>/dev/null
  : >"$DOCK"
  exit 0
fi

agent="${1:-}"; stage="${2:-}"
[ -n "$agent" ] && [ -n "$stage" ] || exit 0
exists "$agent" || exit 0
DOCK="${TMPDIR:-/tmp}/claude-agents-dock.$stage"
docked="$(cat "$DOCK" 2>/dev/null)"

# already docked -> just move focus onto it
if [ "$docked" = "$agent" ]; then
  tmux select-pane -t "$agent" 2>/dev/null
  exit 0
fi

# release whoever is currently docked, then swap the chosen agent in
[ -n "$docked" ] && exists "$docked" && tmux swap-pane -s "$docked" -t "$stage" 2>/dev/null
tmux swap-pane -s "$agent" -t "$stage" 2>/dev/null
printf '%s' "$agent" >"$DOCK"
tmux select-pane -t "$agent" 2>/dev/null
