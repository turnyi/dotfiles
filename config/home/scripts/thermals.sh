#!/usr/bin/env bash
# thermals — CPU / GPU / NVMe temperatures and fan speeds, read straight from
# /sys/class/hwmon plus nvidia-smi for the GPU.
#
#   thermals --segment   compact tmux status segment (CPU°, GPU°, GPU fan)
#   thermals --lines     ANSI block for the proc-menu popup header
#
# Motherboard fan RPMs only exist once the Super I/O driver is loaded
# (nct6775 on the ASRock B660M); without it the fan line shows the GPU only.
set -uo pipefail

hwmon_dir() {
  local f
  for f in /sys/class/hwmon/hwmon*/name; do
    [[ $(<"$f") == "$1" ]] && { printf '%s\n' "${f%/name}"; }
  done
}

millideg() { local v; v=$(<"$1") 2>/dev/null || return 1; printf '%d' $((v / 1000)); }

cpu_temp() {
  local d f
  d=$(hwmon_dir coretemp | head -n1)
  [[ -n $d ]] || d=$(hwmon_dir k10temp | head -n1)
  [[ -n $d ]] || return 1
  for f in "$d"/temp*_label; do
    if [[ $(<"$f") =~ ^(Package|Tctl) ]]; then millideg "${f%_label}_input"; return; fi
  done
  millideg "$d/temp1_input"
}

nvme_temps() {
  local d out=()
  while read -r d; do
    [[ -n $d ]] && out+=("$(millideg "$d/temp1_input")")
  done < <(hwmon_dir nvme)
  local IFS=/; printf '%s' "${out[*]}"
}

read -r GPU_TEMP GPU_FAN < <(
  timeout 2 nvidia-smi --query-gpu=temperature.gpu,fan.speed --format=csv,noheader,nounits 2>/dev/null |
    head -n1 | tr -d ' ' | tr ',' ' '
)
CPU_TEMP=$(cpu_temp 2>/dev/null)

temp_level() {
  local t="${1:-0}"
  if ((t >= 85)); then echo high
  elif ((t >= 70)); then echo warn
  else echo ok; fi
}

board_fans() {
  local d f rpm label
  while read -r d; do
    [[ -n $d ]] || continue
    for f in "$d"/fan*_input; do
      [[ -r $f ]] || continue
      rpm=$(<"$f")
      ((rpm > 0)) || continue
      label=${f##*/}; label=${label%_input}
      [[ -r ${f%_input}_label ]] && label=$(<"${f%_input}_label")
      printf '%s %s\n' "$label" "$rpm"
    done
  done < <(hwmon_dir nct6798; hwmon_dir nct6799; hwmon_dir nct6775; hwmon_dir it8689)
}

segment() {
  declare -A C=([ok]="#a6e3a1" [warn]="#f9e2af" [high]="#f38ba8")
  local out=()
  [[ -n $CPU_TEMP ]] && out+=("#[fg=${C[$(temp_level "$CPU_TEMP")]}]󰔏 ${CPU_TEMP}°")
  [[ -n ${GPU_TEMP:-} ]] && out+=("#[fg=${C[$(temp_level "$GPU_TEMP")]}]󰢮 ${GPU_TEMP}°")
  [[ ${GPU_FAN:-} =~ ^[0-9]+$ ]] && out+=("#[fg=#7f849c]󰈐 ${GPU_FAN}%")
  local IFS=' '
  ((${#out[@]})) && printf '%s#[fg=default]' "${out[*]}"
}

lines() {
  local RED=$'\033[38;2;243;139;168m' YEL=$'\033[38;2;249;226;175m'
  local GRN=$'\033[38;2;166;227;161m' DIM=$'\033[38;2;127;132;156m' RST=$'\033[0m'
  declare -A C=([ok]="$GRN" [warn]="$YEL" [high]="$RED")
  local temps="" fans="" nv name rpm
  [[ -n $CPU_TEMP ]] && temps+=" ${DIM}CPU${RST} ${C[$(temp_level "$CPU_TEMP")]}${CPU_TEMP}°${RST} "
  [[ -n ${GPU_TEMP:-} ]] && temps+=" ${DIM}GPU${RST} ${C[$(temp_level "$GPU_TEMP")]}${GPU_TEMP}°${RST} "
  nv=$(nvme_temps)
  [[ -n $nv ]] && temps+=" ${DIM}NVMe${RST} ${C[$(temp_level "${nv%%/*}")]}${nv//\//°\/}°${RST}"
  [[ ${GPU_FAN:-} =~ ^[0-9]+$ ]] && fans+=" ${DIM}gpu fan${RST} ${GPU_FAN}% "
  while read -r name rpm; do
    [[ -n $name ]] && fans+=" ${DIM}${name,,}${RST} ${rpm} "
  done < <(board_fans)
  printf '%s\n%s' "$temps" "$fans"
}

case "${1:---segment}" in
  --segment) segment ;;
  --lines)   lines ;;
  *)         echo "usage: thermals [--segment|--lines]" >&2; exit 2 ;;
esac
