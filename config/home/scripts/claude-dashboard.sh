#!/usr/bin/env bash
# Claude agents mission control. Two front-ends onto the same set of agents:
#
#   claude-dashboard.sh --popup   floating command-palette (C-g): list + live
#                                 preview; enter=go, ctrl-x=close, tab=pin into
#                                 the workspace, :q/esc=close.
#   claude-dashboard.sh           the tiled WORKSPACE window (prefix g): list on
#                                 the left, pinned agents tiled on the right.
#   claude-dashboard.sh --ensure  build the workspace window if missing WITHOUT
#                                 switching to it; print its stage pane id.
#   claude-dashboard.sh --here    turn the CURRENT pane into the workspace.
set -u
S="$HOME/scripts"

# Build the tiled "agents" workspace window if it doesn't exist yet, without
# selecting it. Prints the stage pane id (existing or freshly built).
ensure_window() {
  local sess win stage list
  sess="$(tmux display -p '#{session_name}' 2>/dev/null)"
  [ -n "$sess" ] || return 1
  if tmux list-windows -t "$sess" -F '#{window_name}' 2>/dev/null | grep -qx agents; then
    tmux show-option -qv -w -t "$sess:agents" @ac_stage
    return 0
  fi
  # stage pane first (right side); keep its id stable via respawn-pane
  win="$(tmux new-window -d -P -F '#{window_id}' -t "$sess" -n agents "exec \${SHELL:-/bin/sh}")"
  stage="$(tmux display -p -t "$win" '#{pane_id}')"
  : >"${TMPDIR:-/tmp}/claude-agents-tiles.$stage"
  : >"${TMPDIR:-/tmp}/claude-agents-sel.$stage"
  tmux respawn-pane -k -t "$stage" "$S/claude-agents-stage.sh $stage"
  # list pane to the LEFT (38%), mission-control mode
  list="$(tmux split-window -h -b -l 38% -P -F '#{pane_id}' -t "$stage" \
    "$S/claude-agents.sh --loop --stage $stage")"
  tmux set-option -w -t "$win" @ac_stage "$stage"
  tmux set-option -w -t "$win" @ac_list "$list"
  tmux set-window-option -t "$win" main-pane-width 38%
  printf '%s' "$stage"
}

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

case "${1:-}" in
  --here)
    build_here
    ;;
  --ensure)
    ensure_window
    ;;
  --popup)
    tmux display-popup -E -w 88% -h 82% -T ' claude mission control ' \
      "$S/claude-agents.sh --popup"
    ;;
  *)
    # the tiled workspace window: build if needed, then switch to it
    sess="$(tmux display -p '#{session_name}' 2>/dev/null)"
    [ -n "$sess" ] || exit 0
    ensure_window >/dev/null
    tmux select-window -t "$sess:agents" 2>/dev/null
    ;;
esac
