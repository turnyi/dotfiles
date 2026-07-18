#!/usr/bin/env bash
# Emit a tmux-styled CPU + RAM usage segment for the status bar.
#
# CPU% is averaged over the gap between calls (tmux status-interval) using a
# stateful /proc/stat delta, so there is no blocking sample on the common path.
# RAM% is (MemTotal - MemAvailable) / MemTotal. Colors shade green -> yellow ->
# red as usage climbs, giving an early warning well before earlyoom's 5% floor.
set -euo pipefail

STATE_FILE="${XDG_RUNTIME_DIR:-/tmp}/tmux-sys-usage-cpu.state"

# Catppuccin Mocha thresholds.
COLOR_OK="#a6e3a1"   # green
COLOR_WARN="#f9e2af" # yellow
COLOR_HIGH="#f38ba8" # red
ICON_CPU="󰻠"
ICON_RAM="󰍛"

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

if [[ -r "$STATE_FILE" ]]; then
  read -r prev_total prev_idle <"$STATE_FILE"
else
  # No history yet: take one short sample so the first render is meaningful.
  prev_total="$cur_total"
  prev_idle="$cur_idle"
  sleep 0.2
  read -r cur_total cur_idle < <(cpu_snapshot)
fi
printf '%s %s\n' "$cur_total" "$cur_idle" >"$STATE_FILE"

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
       END { printf "%d %.1f %.1f\n", (100 * (t - a)) / t, (t - a) / 1048576, t / 1048576 }' \
    /proc/meminfo
)

printf '#[fg=%s]%s %3d%%#[fg=default]  #[fg=%s]%s %s/%sG#[fg=default]' \
  "$(pct_color "$cpu")" "$ICON_CPU" "$cpu" \
  "$(pct_color "$ram_pct")" "$ICON_RAM" "$ram_used" "$ram_total"
