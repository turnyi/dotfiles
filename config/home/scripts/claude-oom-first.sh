#!/usr/bin/env bash
set -euo pipefail

readonly SESSION_ADJ=0
readonly CHILD_ADJ=1000

mark_children() {
  local pid="$1" child
  for child in $(pgrep -P "$pid" || true); do
    choom -n "$CHILD_ADJ" -p "$child" >/dev/null 2>&1 || true
    mark_children "$child"
  done
}

mark_session() {
  local pid="$1"
  choom -n "$SESSION_ADJ" -p "$pid" >/dev/null 2>&1 || true
  mark_children "$pid"
}

mark_owning_session() {
  local pid="$PPID"
  while [[ "$pid" -gt 1 ]]; do
    if [[ "$(cat "/proc/$pid/comm")" == "claude" ]]; then
      mark_session "$pid"
      return 0
    fi
    pid="$(awk '/^PPid:/ {print $2}' "/proc/$pid/status")"
  done
}

mark_all_sessions() {
  local pid
  for pid in $(pgrep -x claude || true); do
    mark_session "$pid"
  done
}

if [[ "${1:-}" == "--all" ]]; then
  mark_all_sessions
else
  mark_owning_session
fi
