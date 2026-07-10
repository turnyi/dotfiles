#!/usr/bin/env bash
# Enter action for the agents list. Vim-like: if the typed query is ":q" (etc.)
# quit mission control; otherwise go to the highlighted agent's pane.
#   claude-agents-enter.sh <query> <agent_pane> [workspace_stage]
# With a workspace stage, ":q" tears down the workspace window; in the floating
# popup (no stage) ":q" just returns so fzf's +abort closes the popup.
set -u
S="$(cd "$(dirname "$0")" && pwd)"
q="${1:-}"; pane="${2:-}"; stage="${3:-}"

case "$q" in
  :q | :q! | :wq | :quit | :qa)
    [ -n "$stage" ] && exec "$S/claude-agents-quit.sh" --now "$stage"
    exit 0 ;;
esac

[ -n "$pane" ] && exec "$S/claude-agents-goto.sh" "$pane"
exit 0
