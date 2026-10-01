#!/usr/bin/env bash
# Emit the tmux status centre groups: CPU usage, GPU usage and RAM. A group's
# temp and fan only appear once its temp reaches HOT_TEMP. Temps and fans come
# from thermals.sh --values.
#
# CPU% is averaged over the gap between calls (tmux status-interval) using a
# stateful /proc/stat delta, so there is no blocking sample on the common path.
# RAM% is (MemTotal - MemAvailable) / MemTotal. Colors shade green -> yellow ->
# red as usage climbs, giving an early warning well before earlyoom's 5% floor.
set -euo pipefail

STATE_FILE="${XDG_RUNTIME_DIR:-/tmp}/tmux-sys-usage-cpu.state"

# Catppuccin Mocha thresholds.
COLOR_OK="#9ed072"   # green
COLOR_WARN="#e7c664" # yellow
COLOR_HIGH="#fc5d7c" # red
ICON_CPU="󰍛"
ICON_RAM="󰘚"
ICON_GPU="󰢮"
ICON_FAN="󰈐"
COLOR_DIM="#7f8490"
HOT_TEMP=70

cpu_snapshot() {
  # Print "total idle" jiffies from the aggregate cpu line of /proc/stat.
  local cpu user nice system idle iowait irq softirq steal rest
  read -r cpu user nice system idle iowait irq softirq steal rest </proc/stat
  printf '%s %s\n' \
    "$((user + nice + system + idle + iowait + irq + softirq + steal))" \
    "$((idle + iowait))"
}

pct_color() {
  local pct="$1"
  if ((pct >= 85)); then
    printf '%s' "$COLOR_HIGH"
  elif ((pct >= 60)); then
    printf '%s' "$COLOR_WARN"
  else
    printf '%s' "$COLOR_OK"
  fi
}

read -r cur_total cur_idle < <(cpu_snapshot)

# Several tmux clients run this concurrently, and a run killed mid-write once
# left the file empty — a failed read here aborted the whole segment.
prev_total="" prev_idle=""
[[ -r "$STATE_FILE" ]] && read -r prev_total prev_idle <"$STATE_FILE" || true
if ! [[ $prev_total =~ ^[0-9]+$ && $prev_idle =~ ^[0-9]+$ ]]; then
  # No history yet: take one short sample so the first render is meaningful.
  prev_total="$cur_total"
  prev_idle="$cur_idle"
  sleep 0.2
  read -r cur_total cur_idle < <(cpu_snapshot)
fi
printf '%s %s\n' "$cur_total" "$cur_idle" >"$STATE_FILE.$$"
mv -f "$STATE_FILE.$$" "$STATE_FILE"

delta_total=$((cur_total - prev_total))
delta_idle=$((cur_idle - prev_idle))
if ((delta_total > 0)); then
  cpu=$(((100 * (delta_total - delta_idle)) / delta_total))
else
  cpu=0
fi

# ram_pct drives the color; used/total (in GiB, one decimal) is what we show.
read -r ram_pct ram_used ram_total < <(
  awk '/^MemTotal:/ {t = $2} /^MemAvailable:/ {a = $2}
       END { printf "%d %d %d\n", (100 * (t - a)) / t, (t - a) / 1048576, t / 1048576 }' \
    /proc/meminfo
)

temp_color() {
  local t="$1"
  if ((t >= 85)); then
    printf '%s' "$COLOR_HIGH"
  elif ((t >= HOT_TEMP)); then
    printf '%s' "$COLOR_WARN"
  else
    printf '%s' "$COLOR_OK"
  fi
}

read -r cpu_temp cpu_fan gpu_temp gpu_fan gpu_util < <(
  "$(dirname "$0")/thermals.sh" --values 2>/dev/null || echo "- - - - -"
)

cpu_group="#[fg=$(pct_color "$cpu")]$ICON_CPU $(printf '%3d' "$cpu")%"
if [[ $cpu_temp != - ]] && ((cpu_temp >= HOT_TEMP)); then
  cpu_group+=" #[fg=$(temp_color "$cpu_temp")]${cpu_temp}°"
  [[ $cpu_fan != - ]] && cpu_group+=" #[fg=$COLOR_DIM]$ICON_FAN ${cpu_fan}"
fi

gpu_group=""
if [[ $gpu_util != - ]]; then
  gpu_group="#[fg=$(pct_color "$gpu_util")]$ICON_GPU $(printf '%3d' "$gpu_util")%"
  if [[ $gpu_temp != - ]] && ((gpu_temp >= HOT_TEMP)); then
    gpu_group+=" #[fg=$(temp_color "$gpu_temp")]${gpu_temp}°"
    [[ $gpu_fan != - ]] && gpu_group+=" #[fg=$COLOR_DIM]$ICON_FAN ${gpu_fan}%"
  fi
fi

ram_group="#[fg=$(pct_color "$ram_pct")]$ICON_RAM $ram_used/$ram_total GB"

printf '%s#[fg=default]  ' "$cpu_group"
[[ -n $gpu_group ]] && printf '%s#[fg=default]  ' "$gpu_group"
printf '%s#[fg=default]' "$ram_group"
