#!/usr/bin/env bash
# Prints "artist - title" of the first player that is actually playing, or
# nothing at all, so every bar can hide its segment on empty output.
set -uo pipefail

MAX_CHARS="${1:-40}"

linux_track() {
  command -v playerctl >/dev/null 2>&1 || return 0
  timeout 2 playerctl -a metadata --format $'{{status}}\t{{artist}}\t{{title}}' 2>/dev/null |
    awk -F'\t' '$1 == "Playing" && $3 != "" { print $2 "\t" $3; exit }'
}

# macOS 15.4 locked MediaRemote to Apple-signed binaries, so nowplaying-cli and
# sketchybar's media_change event stopped reporting; media-control still works.
mac_track() {
  command -v media-control >/dev/null 2>&1 || return 0
  timeout 2 media-control get 2>/dev/null |
    jq -r 'select(. != null and .playing == true and (.title // "") != "") | "\(.artist // "")\t\(.title)"'
}

case "$(uname -s)" in
  Darwin) track=$(mac_track) ;;
  *) track=$(linux_track) ;;
esac
[ -n "$track" ] || exit 0

IFS=$'\t' read -r artist title <<<"$track"
text="$title"
[ -n "$artist" ] && text="$artist - $title"
if ((${#text} > MAX_CHARS)); then
  text="${text:0:MAX_CHARS-1}…"
fi
printf '%s\n' "$text"
