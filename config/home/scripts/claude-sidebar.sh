#!/usr/bin/env bash
# claude-sidebar.sh — toggle a narrow fleet list on the left of the current window
# (prefix S, which passes its pane). One sidebar per window; it remembers its pane id in @fleet_sidebar.
set -u
S="$(cd "$(dirname "$0")" && pwd)"
cur="${1:-$(tmux display -p '#{pane_id}')}"
win="$(tmux display -p -t "$cur" '#{window_id}')"
side="$(tmux show-option -qv -w -t "$win" @fleet_sidebar 2>/dev/null)"
if [ -n "$side" ] && tmux list-panes -t "$win" -F '#{pane_id}' | grep -qx "$side"; then
  tmux kill-pane -t "$side"
  tmux set-option -w -t "$win" -u @fleet_sidebar
  exit 0
fi
side="$(tmux split-window -h -b -l 46 -P -F '#{pane_id}' -t "$cur" "$S/claude-fleet.sh --sidebar")"
tmux set-option -w -t "$win" @fleet_sidebar "$side"
tmux select-pane -t "$cur"
