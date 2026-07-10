#!/bin/sh
input=$(cat)
transcript=$(echo "$input" | jq -r '.transcript_path // empty')
[ -n "$transcript" ] && [ -f "$transcript" ] || exit 0

title=$(jq -r 'select(.type=="custom-title" or .type=="ai-title") | (.customTitle // .aiTitle)' "$transcript" 2>/dev/null | tail -1)
[ -z "$title" ] && exit 0

printf "%s" "$title"
