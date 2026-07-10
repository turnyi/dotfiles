#!/bin/sh
input=$(cat)
cwd=$(echo "$input" | jq -r '.worktree.path // .workspace.current_dir // .cwd // empty')
[ -z "$cwd" ] && cwd="$PWD"

slots_dir="$HOME/.centinel-slots"
[ -d "$slots_dir" ] || exit 0

for lock in "$slots_dir"/slot-*.lock; do
  [ -f "$lock" ] || continue
  info=$(jq -r '"\(.worktree // "")\n\(.slot // "")\n\(.pid // "")"' "$lock" 2>/dev/null)
  worktree=$(echo "$info" | sed -n '1p')
  slot=$(echo "$info" | sed -n '2p')
  pid=$(echo "$info" | sed -n '3p')
  [ -n "$worktree" ] || continue

  case "$cwd" in
    "$worktree"*)
      port=$((3000 + slot - 1))
      if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
        printf "slot %s · :%s" "$slot" "$port"
      else
        printf "slot %s (down)" "$slot"
      fi
      exit 0
      ;;
  esac
done
