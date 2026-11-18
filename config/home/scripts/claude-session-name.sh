#!/usr/bin/env bash
set -u
in=$(cat)
[ -n "$(jq -r '.session_title // .session_name // empty' <<<"$in")" ] && exit 0
dir=$(jq -r '.cwd // empty' <<<"$in")
dir=${dir:-$PWD}
branch=$(git -C "$dir" branch --show-current 2>/dev/null)
[ -z "$branch" ] && exit 0
key=$(grep -oiE '[a-z]+-[0-9]+' <<<"${branch##*/}" | head -1 | tr '[:lower:]' '[:upper:]')
title="${branch##*/}"
if [ -n "$key" ]; then
  title="$key"
  root=$(git -C "$dir" rev-parse --show-toplevel 2>/dev/null)
  api_key=${LINEAR_API_KEY:-$(sed -nE 's/^LINEAR_API_KEY=["'\'']?([^"'\'']*)["'\'']?$/\1/p' "$root/.env" 2>/dev/null | head -1)}
  [ -z "$api_key" ] && api_key=$(timeout 3 doppler secrets get LINEAR_API_KEY --project centinel-v2 --config dev --plain 2>/dev/null)
  if [ -n "$api_key" ]; then
    query=$(jq -nc --arg id "$key" '{query: "query($id:String!){issue(id:$id){title}}", variables: {id: $id}}')
    name=$(curl -s -m 4 https://api.linear.app/graphql -H "Content-Type: application/json" \
      -H "Authorization: $api_key" -d "$query" | jq -r '.data.issue.title // empty' 2>/dev/null)
    [ -n "$name" ] && title="$key $name"
  fi
  if [ "$title" = "$key" ]; then
    pr=$(cd "$dir" && timeout 4 gh pr view --json title -q .title 2>/dev/null)
    [ -n "$pr" ] && title="$key $pr"
  fi
fi
jq -n --arg t "$title" '{hookSpecificOutput: {hookEventName: "SessionStart", sessionTitle: $t}}'
