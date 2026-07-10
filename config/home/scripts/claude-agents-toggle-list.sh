#!/usr/bin/env bash
# Toggle the navigator (fzf list) pane in the mission-control window: break it
# away to a hidden window to reclaim the whole screen for agents, or join it back
# on the left. Bound to C-b (scoped to the "agents" window) in tmux.conf.
set -u

name="$(tmux display -p '#{window_name}' 2>/dev/null)"
[ "$name" = agents ] || exit 0
win="$(tmux display -p '#{window_id}' 2>/dev/null)"
list="$(tmux show-option -qv -w -t "$win" @ac_list)"
stage="$(tmux show-option -qv -w -t "$win" @ac_stage)"
[ -n "$list" ] || exit 0

if tmux list-panes -t "$win" -F '#{pane_id}' 2>/dev/null | grep -qx "$list"; then
  # currently visible -> hide it (and re-tile the agents that remain)
  tmux break-pane -d -s "$list" -n _agents_list_hidden 2>/dev/null
  tmux select-layout -t "$win" tiled 2>/dev/null
else
  # currently hidden -> bring it back on the left, list as the main pane
  tmux join-pane -h -b -l 38% -s "$list" -t "$stage" 2>/dev/null
  tmux set-window-option -t "$win" main-pane-width 38% 2>/dev/null
  tmux select-layout -t "$win" main-vertical 2>/dev/null
  tmux select-pane -t "$list" 2>/dev/null
fi
