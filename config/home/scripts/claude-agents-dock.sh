#!/usr/bin/env bash
# Dock Claude panes into the mission-control "stage" as tiles, using swap-pane so
# each agent returns to its exact home slot when released.
#
#   claude-agents-dock.sh <agent> <stage>        toggle: add as a tile, or focus if already tiled
#   claude-agents-dock.sh --untile <agent> <stage>   send that agent home
#   claude-agents-dock.sh --untile-all <stage>       send every tiled agent home
#
# State: one line per docked tile in $TILES -> "<agent_pane_id>\t<placeholder_pane_id>".
# The placeholder is a throwaway shell that swaps into the agent's home slot while
# the agent is on the stage; releasing swaps them back and kills the placeholder.
set -u

exists() { tmux display -p -t "$1" '#{pane_id}' >/dev/null 2>&1; }
win_of() { tmux display -p -t "$1" '#{window_id}' 2>/dev/null; }

# Re-tile the agents window: list as the main pane on the left, agent tiles
# stacked on the right. If the list is hidden, just tile the stage evenly.
relayout() {
  local anchor="$1" w list
  w="$(win_of "$anchor")" || return 0
  [ -n "$w" ] || return 0
  list="$(tmux show-option -qv -w -t "$w" @ac_list)"
  if [ -n "$list" ] && tmux list-panes -t "$w" -F '#{pane_id}' 2>/dev/null | grep -qx "$list"; then
    tmux set-window-option -t "$w" main-pane-width 38% 2>/dev/null
    tmux select-layout -t "$w" main-vertical 2>/dev/null
  else
    tmux select-layout -t "$w" tiled 2>/dev/null
  fi
}

untile_one() { # <agent> <stage> <tiles_file>
  local agent="$1" stage="$2" TILES="$3" line ph
  line="$(grep -m1 "^$agent"$'\t' "$TILES" 2>/dev/null)" || return 1
  [ -n "$line" ] || return 1
  ph="${line#*$'\t'}"
  if exists "$agent" && exists "$ph"; then
    tmux swap-pane -s "$agent" -t "$ph" 2>/dev/null   # agent goes home, placeholder returns to stage
  fi
  exists "$ph" && tmux kill-pane -t "$ph" 2>/dev/null
  grep -v "^$agent"$'\t' "$TILES" >"$TILES.tmp" 2>/dev/null && mv -f "$TILES.tmp" "$TILES"
}

# ---- dispatch ---------------------------------------------------------------
case "${1:-}" in
  --untile-all)
    stage="${2:-}"; [ -n "$stage" ] || exit 0
    TILES="${TMPDIR:-/tmp}/claude-agents-tiles.$stage"
    [ -f "$TILES" ] || exit 0
    while IFS=$'\t' read -r agent _; do
      [ -n "$agent" ] && untile_one "$agent" "$stage" "$TILES"
    done < <(cat "$TILES")
    : >"$TILES"
    relayout "$stage"
    exit 0 ;;
  --untile)
    agent="${2:-}"; stage="${3:-}"
    [ -n "$agent" ] && [ -n "$stage" ] || exit 0
    TILES="${TMPDIR:-/tmp}/claude-agents-tiles.$stage"
    untile_one "$agent" "$stage" "$TILES" && relayout "$stage"
    exit 0 ;;
esac

# default: toggle this agent's tile on the stage (stay in the list either way)
agent="${1:-}"; stage="${2:-}"
[ -n "$agent" ] && [ -n "$stage" ] || exit 0
exists "$agent" || exit 0
TILES="${TMPDIR:-/tmp}/claude-agents-tiles.$stage"
: >>"$TILES"

# already a tile -> unpin it
if grep -q "^$agent"$'\t' "$TILES" 2>/dev/null; then
  untile_one "$agent" "$stage" "$TILES"
  relayout "$stage"
  exit 0
fi

# new tile: split a detached placeholder off the stage, swap the real agent in.
# -d keeps focus in the list so you can pin several agents in a row.
ph="$(tmux split-window -d -P -F '#{pane_id}' -t "$stage" "exec \${SHELL:-/bin/sh}")" || exit 0
tmux swap-pane -d -s "$agent" -t "$ph" 2>/dev/null
printf '%s\t%s\n' "$agent" "$ph" >>"$TILES"
relayout "$stage"
