#!/usr/bin/env bash
# Focus the Chrome window that belongs to a given profile, or launch one.
#
# Chrome runs every profile inside ONE browser process and gives every normal
# window the same "google-chrome" app_id, so nothing hyprctl exposes (class,
# pid, initialTitle) says which profile a window belongs to. The tell: a
# window's title is the title of a page that profile visited — so match the
# open window titles against the profile's History database. The db is locked
# while Chrome runs, so query a throwaway copy. Ambiguous titles ("New Tab")
# fall through to launching, which at worst opens one extra window.
set -uo pipefail

PROFILE="${1:?usage: chrome-profile-focus.sh <profile-directory>}"
HIST="$HOME/.config/google-chrome/$PROFILE/History"

launch() {
  setsid -f google-chrome-stable --profile-directory="$PROFILE" >/dev/null 2>&1
  exit 0
}

windows=$(hyprctl clients -j 2>/dev/null |
  jq -r '.[] | select(.class == "google-chrome") | [.address, .title] | @tsv')
[ -n "$windows" ] || launch
[ -r "$HIST" ] || launch

tmp=$(mktemp)
trap 'rm -f "$tmp"' EXIT
cp "$HIST" "$tmp"
titles=$(sqlite3 "$tmp" \
  "SELECT DISTINCT title FROM urls WHERE title != '' ORDER BY last_visit_time DESC LIMIT 400;" 2>/dev/null)
[ -n "$titles" ] || launch

while IFS=$'\t' read -r address title; do
  page="${title% - Google Chrome}"
  [ -n "$page" ] || continue
  if grep -Fxq "$page" <<<"$titles"; then
    hyprctl dispatch focuswindow "address:$address" >/dev/null
    exit 0
  fi
done <<<"$windows"

launch
