#!/usr/bin/env bash
set -euo pipefail

save="$3"
path="$4"
out="$5"
debug="${6:-0}"

[[ "$debug" == "1" ]] && set -x

start="$path"
[[ "$save" == "1" ]] && start="$(dirname "$path")"

${TERMCMD:-kitty --class termfilechooser} spf --chooser-file="$out" "$start"

# In save mode superfile's `E` hands back the folder, not a file, so the
# suggested filename has to be appended for the portal to get a save target.
if [[ "$save" == "1" && -s "$out" ]]; then
  chosen="$(cat "$out")"
  if [[ -d "$chosen" ]]; then
    printf "%s/%s" "$chosen" "$(basename "$path")" >"$out"
  fi
fi
