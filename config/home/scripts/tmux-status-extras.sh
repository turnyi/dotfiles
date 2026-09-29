#!/usr/bin/env bash
# tmux twin of the waybar right-side modules (♪ now playing, ⇄ port-forwards, 🔔 notifications,
# volume, battery, network, bluetooth). One process per status-interval instead
# of six #() jobs. Every segment is guarded, so machines without the tool (or a
# battery) simply drop the segment instead of printing garbage.
#
# Glyphs by codepoint so the raw PUA bytes never live in this file — they were
# silently stripped by an editor round-trip once already in the waybar scripts.
set -uo pipefail

# Every probe goes through `timeout`: a dead swaync daemon leaves `swaync-client`
# blocked on D-Bus forever, which stalls the whole status line ("not ready" in
# tmux) and piles up one orphan client per status-interval.
run() { timeout 2 "$@"; }

DIM="#7f8490"
TEXT="#e2e2e3"
BLUE="#76cce0"
PEACH="#f39660"
RED="#fc5d7c"
GREEN="#9ed072"
MAGENTA="#b39df3"

ICON_MUSIC=$'\U000f075a'
ICON_PF=$'\uf0ec'
ICON_BELL=$'\U000f009a'
ICON_BELL_OFF=$'\U000f009c'
ICON_VOL_MUTE=$'\U000f075f'
ICON_VOL_LOW=$'\U000f0580'
ICON_VOL_HIGH=$'\U000f057e'
ICON_PLUG=$'\uf1e6'
ICON_BAT=($'\uf244' $'\uf243' $'\uf242' $'\uf241' $'\uf240')
ICON_WIFI=$'\U000f05a9'
ICON_WIFI_OFF=$'\U000f05aa'
ICON_ETH=$'\U000f0200'
ICON_BT=$'\U000f00af'

segments=()

now_playing() {
  local script="$HOME/scripts/now-playing.sh" track
  [ -x "$script" ] || return 0
  track=$(run "$script" 30) || return 0
  [ -n "$track" ] || return 0
  segments+=("#[fg=$MAGENTA]$ICON_MUSIC ${track//#/##}")
}

port_forwards() {
  local pf="$HOME/scripts/pf-ctl.sh" running=0 status
  [ -x "$pf" ] || return 0
  while IFS='|' read -r name _ _ _ status; do
    [ -n "$name" ] && [ "$status" = "on" ] && running=$((running + 1))
  done <<<"$(run "$pf" list 2>/dev/null)"
  if ((running > 0)); then
    segments+=("#[fg=$GREEN]$ICON_PF $running")
  else
    segments+=("#[fg=$DIM]$ICON_PF")
  fi
}

notifications() {
  command -v swaync-client >/dev/null 2>&1 || return 0
  pgrep -x swaync >/dev/null 2>&1 || return 0
  local count dnd
  count=$(run swaync-client -c 2>/dev/null) || return 0
  dnd=$(run swaync-client -D 2>/dev/null) || dnd=false
  local glyph="$ICON_BELL"
  [ "$dnd" = "true" ] && glyph="$ICON_BELL_OFF"
  if [ "$dnd" = "true" ]; then
    segments+=("#[fg=$PEACH]$glyph")
  elif ((${count:-0} > 0)); then
    segments+=("#[fg=$RED]$glyph $count")
  else
    segments+=("#[fg=$DIM]$glyph")
  fi
}

volume() {
  command -v wpctl >/dev/null 2>&1 || return 0
  local out vol pct
  out=$(run wpctl get-volume @DEFAULT_AUDIO_SINK@ 2>/dev/null) || return 0
  vol=$(awk '{print $2}' <<<"$out")
  pct=$(awk -v v="$vol" 'BEGIN { printf "%d", v * 100 }')
  if [[ "$out" == *MUTED* ]]; then
    segments+=("#[fg=$DIM]$ICON_VOL_MUTE")
  elif ((pct < 50)); then
    segments+=("#[fg=$MAGENTA]$ICON_VOL_LOW $pct%")
  else
    segments+=("#[fg=$MAGENTA]$ICON_VOL_HIGH $pct%")
  fi
}

battery() {
  command -v upower >/dev/null 2>&1 || return 0
  local bat info state percent icon color
  bat=$(run upower -e 2>/dev/null | grep 'BAT') || return 0
  info=$(run upower -i "$bat") || return 0
  state=$(awk -F': ' '/state/ {print tolower($2)}' <<<"$info" | xargs)
  percent=$(awk -F': ' '/percentage/ {print $2}' <<<"$info" | tr -d '%' | xargs)
  [ -n "$percent" ] || return 0

  if ((percent < 15)); then
    icon="${ICON_BAT[0]}"
  elif ((percent < 40)); then
    icon="${ICON_BAT[1]}"
  elif ((percent < 60)); then
    icon="${ICON_BAT[2]}"
  elif ((percent < 80)); then
    icon="${ICON_BAT[3]}"
  else
    icon="${ICON_BAT[4]}"
  fi
  if ((percent < 15)); then
    color="#fc5d7c"
  elif ((percent < 40)); then
    color="#e7c664"
  elif ((percent < 75)); then
    color="#9ed072"
  else
    color="#76cce0"
  fi
  case "$state" in charging | fully-charged) icon="$ICON_PLUG" ;; esac
  segments+=("#[fg=$color]$percent% $icon")
}

network() {
  command -v nmcli >/dev/null 2>&1 || return 0
  local devices
  devices=$(run nmcli -t -f TYPE,STATE device 2>/dev/null) || return 0
  if grep -qx 'wifi:connected' <<<"$devices"; then
    segments+=("#[fg=$TEXT]$ICON_WIFI")
  elif grep -qx 'ethernet:connected' <<<"$devices"; then
    segments+=("#[fg=$TEXT]$ICON_ETH")
  else
    segments+=("#[fg=$RED]$ICON_WIFI_OFF")
  fi
}

bluetooth() {
  command -v bluetoothctl >/dev/null 2>&1 || return 0
  local count
  count=$(run bluetoothctl devices Connected 2>/dev/null | grep -c '^Device') || count=0
  if ((count > 0)); then
    segments+=("#[fg=$BLUE]$ICON_BT $count")
  else
    segments+=("#[fg=$DIM]$ICON_BT")
  fi
}

now_playing
port_forwards
notifications
volume
battery
network
bluetooth

out=""
for s in "${segments[@]}"; do
  out+="$s#[fg=default]  "
done
printf '%s' "${out%  }"
