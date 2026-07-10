#!/usr/bin/env bash
# Pin an agent (from the floating popup) into the tiled workspace window: make
# sure the workspace exists (built in the background), then dock the agent there.
#   claude-agents-pin.sh <agent_pane_id>
set -u
S="$(cd "$(dirname "$0")" && pwd)"
agent="${1:-}"
[ -n "$agent" ] || exit 0

stage="$("$S/claude-dashboard.sh" --ensure)"
[ -n "$stage" ] || exit 0
"$S/claude-agents-dock.sh" "$agent" "$stage"
