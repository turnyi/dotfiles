#!/usr/bin/env bash
# Close (kill) a Claude agent pane from the dashboard.
# If the agent is currently docked onto the stage, release it home first so the
# stage layout is restored, then kill the pane.
#   claude-agents-kill.sh <agent_pane_id> [stage_pane_id]
set -u

exists() { tmux display -p -t "$1" '#{pane_id}' >/dev/null 2>&1; }

agent="${1:-}"; stage="${2:-}"
[ -n "$agent" ] || exit 0
exists "$agent" || exit 0

# If this agent is docked on the stage, send it home first (restores the stage).
if [ -n "$stage" ]; then
  DOCK="${TMPDIR:-/tmp}/claude-agents-dock.$stage"
  docked="$(cat "$DOCK" 2>/dev/null)"
  if [ "$docked" = "$agent" ]; then
    exists "$docked" && tmux swap-pane -s "$docked" -t "$stage" 2>/dev/null
    : >"$DOCK"
  fi
fi

tmux kill-pane -t "$agent" 2>/dev/null
