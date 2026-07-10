#!/usr/bin/env bash
# Pull a Claude pane in next to the dashboard (open it "on the right of the list").
# Send it back to its own window afterwards with:  prefix + !  (break-pane)
# Usage: claude-agents-join.sh <pane_id> <dashboard_target>
set -u
p="${1:-}"
dash="${2:-}"
[ -n "$p" ] && [ -n "$dash" ] || exit 0
tmux join-pane -h -l 62% -s "$p" -t "$dash" 2>/dev/null
