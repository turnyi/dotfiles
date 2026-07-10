#!/usr/bin/env bash
# Build (or focus) the Claude agents mission-control layout:
#   left  = agent list (navigator)   right = "stage" (live preview / docked agent)
#
#   claude-dashboard.sh          open/focus a dedicated "agents" window (prefix G)
#   claude-dashboard.sh --here   turn the CURRENT pane into the layout (tmuxinator)
set -u
S="$HOME/scripts"

build_here() {
  # The current pane becomes the stage; a list pane is split off to its left.
  local self stage list
  self="$(tmux display -p '#{pane_id}')"
  stage="$self"
  : >"${TMPDIR:-/tmp}/claude-agents-tiles.$stage"
  : >"${TMPDIR:-/tmp}/claude-agents-sel.$stage"
  list="$(tmux split-window -h -b -l 38% -P -F '#{pane_id}' -t "$self" \
    "$S/claude-agents.sh --loop --stage $stage")"
  tmux set-option -w @ac_stage "$stage"
  tmux set-option -w @ac_list "$list"
  tmux set-window-option main-pane-width 38%
  tmux select-pane -t "$list"
  exec "$S/claude-agents-stage.sh" "$stage"
}

if [ "${1:-}" = --here ]; then
  build_here
  exit 0
fi

sess="$(tmux display -p '#{session_name}' 2>/dev/null)"
[ -n "$sess" ] || exit 0

if tmux list-windows -t "$sess" -F '#{window_name}' 2>/dev/null | grep -qx agents; then
  tmux select-window -t "$sess:agents"
  exit 0
fi

# stage pane first (becomes the right pane); keep its id stable via respawn-pane
win="$(tmux new-window -P -F '#{window_id}' -t "$sess" -n agents "exec \${SHELL:-/bin/sh}")"
stage="$(tmux display -p -t "$win" '#{pane_id}')"
: >"${TMPDIR:-/tmp}/claude-agents-tiles.$stage"
: >"${TMPDIR:-/tmp}/claude-agents-sel.$stage"
tmux respawn-pane -k -t "$stage" "$S/claude-agents-stage.sh $stage"

# list pane to the LEFT (38%), running in mission-control mode
list="$(tmux split-window -h -b -l 38% -P -F '#{pane_id}' -t "$stage" \
  "$S/claude-agents.sh --loop --stage $stage")"

# remember which pane is which so the toggle/relayout helpers can find them
tmux set-option -w -t "$win" @ac_stage "$stage"
tmux set-option -w -t "$win" @ac_list "$list"
tmux set-window-option -t "$win" main-pane-width 38%
tmux select-pane -t "$list"

# To pin the dashboard as window 0 instead of appending, uncomment:
# tmux swap-window -d -s "$win" -t "$sess:0" 2>/dev/null || true
