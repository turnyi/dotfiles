#!/usr/bin/env bash
# centinel-slots.sh — dev-stack slot occupancy, read from the lock files that
# centinel's dev-local.sh writes (~/.centinel-slots/slot-N.lock).
#
#   centinel-slots.sh            one TSV row per slot: slot, worktree, branch, alive, port
#   centinel-slots.sh --summary  "used/max"
#   centinel-slots.sh --for DIR  the slot held by DIR (or a parent worktree), if any
#
# The ceiling mirrors scripts/lib-slots.sh in the centinel repo: CENTINEL_MAX_SLOTS,
# else one slot per 8GB after leaving 8GB to the OS, never below 1.
set -u

SLOTS_DIR="${SLOTS_DIR:-$HOME/.centinel-slots}"

max_slots() {
  if [ -n "${CENTINEL_MAX_SLOTS:-}" ]; then echo "$CENTINEL_MAX_SLOTS"; return; fi
  local kb gb n
  kb="$(awk '/^MemTotal:/ {print $2}' /proc/meminfo 2>/dev/null)"
  [ -n "$kb" ] || { echo 2; return; }
  gb=$((kb / 1048576)); n=$(((gb - 8) / 8))
  [ "$n" -lt 1 ] && n=1
  echo "$n"
}

rows() {
  local lock slot worktree branch pid alive
  for lock in "$SLOTS_DIR"/slot-*.lock; do
    [ -f "$lock" ] || continue
    IFS=$'\t' read -r slot worktree branch pid < <(jq -r '[.slot, .worktree, .branch // "", .pid] | @tsv' "$lock" 2>/dev/null)
    [ -n "${slot:-}" ] || continue
    alive=0
    [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null && alive=1
    printf '%s\t%s\t%s\t%s\t%s\n' "$slot" "$worktree" "$branch" "$alive" "$((3000 + slot - 1))"
  done
}

case "${1:-}" in
  --summary)
    used="$(rows | awk -F'\t' '$4 == 1' | wc -l | tr -d ' ')"
    printf '%s/%s\n' "$used" "$(max_slots)"
    ;;
  --for)
    dir="${2:-}"
    rows | while IFS=$'\t' read -r slot worktree branch alive port; do
      case "$dir" in
        "$worktree" | "$worktree"/*) printf '%s\t%s\t%s\n' "$slot" "$alive" "$port"; exit 0 ;;
      esac
    done
    ;;
  *) rows ;;
esac
