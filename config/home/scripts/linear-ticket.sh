#!/bin/sh
input=$(cat)
cwd=$(echo "$input" | jq -r '.workspace.current_dir // .cwd // .worktree.path // empty')
[ -z "$cwd" ] && cwd="$PWD"

branch=$(git -C "$cwd" branch --show-current 2>/dev/null)
[ -z "$branch" ] && exit 0

ticket=$(echo "$branch" | grep -oiE 'en-[0-9]+' | head -1)
[ -z "$ticket" ] && exit 0

printf "%s" "$(echo "$ticket" | tr '[:lower:]' '[:upper:]')"
