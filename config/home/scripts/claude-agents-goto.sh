#!/usr/bin/env bash
# Focus a specific Claude pane (jump the client to its session/window/pane).
# Usage: claude-agents-goto.sh <pane_id>
set -u
p="${1:-}"
[ -n "$p" ] || exit 0
sess="$(tmux display -p -t "$p" '#{session_name}' 2>/dev/null)" || exit 0
[ -n "$sess" ] && tmux switch-client -t "$sess" 2>/dev/null
tmux select-window -t "$p" 2>/dev/null
tmux select-pane -t "$p" 2>/dev/null
