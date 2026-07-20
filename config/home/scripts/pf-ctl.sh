#!/usr/bin/env bash
# pf-ctl — start / stop / inspect a set of named SSH port-forward tunnels and
# expose their state to sketchybar. Tunnels run detached; each one's pid and log
# are tracked per name under $RUN_DIR.
#
# Every registered command ends in `exec ssh -N …`, so the pid we record ends up
# being the ssh process itself — a plain `kill` tears the tunnel down cleanly.
#
# The Centinel and Optitask dev harnesses run several parallel dev environments
# ("slots"), each forwarding its own port set. This exposes one togglable menu
# row per slot, so you can tunnel to whichever slot you want and see at a glance
# which are live. Slot ranges are configurable:
#     PF_CENTINEL_SLOTS="0 1 2 3"   (Next port 3000+slot, emulators 4000+/8080+…)
#     PF_OPTITASK_SLOTS="1 2 3 4"   (web 9200+(slot-1)*10, api 3333+(slot-1)*10)
# Add your own generic `pf` forwards to ~/.config/pf/tunnels.conf as
# `name|label|command` lines; they show up under a "Custom" group, e.g.
#     db|DB prod|exec ~/scripts/pf.sh bastion 5432:db.internal:5432
#
# Registry rows are `name|group|label|detail|command` (command may contain `|`).
#
# Subcommands:
#   list                  name|group|label|detail|on|off  (one per line, sketchybar)
#   status <name>         prints on|off, exit 0 if running
#   start  <name>
#   stop   <name>
#   toggle <name>
#   stop-all
set -uo pipefail

RUN_DIR="${XDG_RUNTIME_DIR:-$HOME/.cache}/pf"
USER_CONF="${XDG_CONFIG_HOME:-$HOME/.config}/pf/tunnels.conf"
ADHOC_CONF="$RUN_DIR/adhoc.conf"   # ports opened on the fly via `open`
mkdir -p "$RUN_DIR"

# Default ssh host for ad-hoc `open` forwards: $PF_HOST, else whichever dev
# tunnel host is configured.
default_host() {
  if [ -n "${PF_HOST:-}" ]; then printf '%s' "$PF_HOST"; return; fi
  local f
  for f in "$HOME/.centinel-tunnel-host" "$HOME/.optitask-tunnel-host"; do
    [ -f "$f" ] && { head -1 "$f"; return; }
  done
}

CENTINEL_DIR="$HOME/Projects/Centinel/centinel-app"
OPTITASK_DIR="$HOME/Projects/Optitask/Web"
CENTINEL_SLOTS="${PF_CENTINEL_SLOTS:-0 1 2 3}"
OPTITASK_SLOTS="${PF_OPTITASK_SLOTS:-1 2 3 4}"

# ── Tunnel registry ───────────────────────────────────────────────────
# One row per dev slot, plus any user-defined generic forwards. `detail` is the
# primary localhost port the slot serves, shown next to the row in the menu.
default_registry() {
  local s
  for s in $CENTINEL_SLOTS; do
    printf 'centinel-%s|Centinel|slot %s|:%s|cd "%s" && exec ./scripts/dev-tunnel.sh %s\n' \
      "$s" "$s" "$((3000 + s))" "$CENTINEL_DIR" "$s"
  done
  for s in $OPTITASK_SLOTS; do
    printf 'optitask-%s|Optitask|slot %s|:%s|cd "%s" && exec ./scripts/dev/dev-tunnel.sh %s\n' \
      "$s" "$s" "$((9200 + (s - 1) * 10))" "$OPTITASK_DIR" "$s"
  done
}

user_registry() {
  [ -f "$USER_CONF" ] || return 0
  # User rows are the short `name|label|command` form; normalise to 5 fields.
  grep -vE '^[[:space:]]*(#|$)' "$USER_CONF" | while IFS='|' read -r name label cmd; do
    [ -n "$name" ] || continue
    printf '%s|Custom|%s||%s\n' "$name" "$label" "$cmd"
  done
}

# Ad-hoc `open` tunnels, already in the 5-field form.
adhoc_registry() {
  [ -f "$ADHOC_CONF" ] && grep -vE '^[[:space:]]*(#|$)' "$ADHOC_CONF"
  return 0
}

registry() {
  default_registry
  user_registry
  adhoc_registry
}

# Expand a port spec ("5555, 55510  8888-8889") to one port per line, deduped.
parse_ports() {
  local raw="$*" tok a b p
  raw="${raw//,/ }"
  for tok in $raw; do
    if [[ "$tok" =~ ^([0-9]+)-([0-9]+)$ ]]; then
      a="${BASH_REMATCH[1]}"; b="${BASH_REMATCH[2]}"
      (( a <= b )) && for ((p = a; p <= b; p++)); do echo "$p"; done
    elif [[ "$tok" =~ ^[0-9]+$ ]]; then
      echo "$tok"
    fi
  done | awk '!seen[$0]++'
}

lookup() { # lookup <name> -> prints matching registry line, or nothing
  registry | awk -F'|' -v n="$1" '$1==n {print; exit}'
}

field() { printf '%s' "$1" | cut -d'|' -f"$2"; }

pidfile() { printf '%s/%s.pid' "$RUN_DIR" "$1"; }
logfile() { printf '%s/%s.log' "$RUN_DIR" "$1"; }

# Primary local port a slot forwards (empty for custom tunnels without one).
port_of() { printf '%s' "$(field "$(lookup "$1")" 4)" | tr -d ' :'; }

# A slot is "on" if *anything* is forwarding its primary port — whether we
# started it or the project's own dev-tunnel.sh did (it forwards PORT:localhost:PORT).
# Custom tunnels with no known port fall back to our own pidfile.
is_running() { # is_running <name>
  local name="$1" port pf pid
  port="$(port_of "$name")"
  if [ -n "$port" ]; then
    pgrep -f "${port}:localhost:${port}" >/dev/null 2>&1
    return
  fi
  pf="$(pidfile "$name")"
  [ -f "$pf" ] || return 1
  pid="$(cat "$pf" 2>/dev/null)"
  [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null
}

refresh_bar() { command -v sketchybar >/dev/null 2>&1 && sketchybar --trigger pf_update 2>/dev/null || true; }

start_one() { # start_one <name>
  local name="$1" line cmd
  is_running "$name" && return 0
  line="$(lookup "$name")"
  [ -n "$line" ] || { echo "unknown tunnel: $name" >&2; return 1; }
  cmd="$(field "$line" 5-)"
  # Detached; the recorded pid becomes ssh after the command's exec chain, so
  # its lifetime tracks the tunnel and `kill` stops it.
  nohup bash -c "$cmd" >"$(logfile "$name")" 2>&1 &
  echo $! > "$(pidfile "$name")"
  refresh_bar
}

stop_one() { # stop_one <name>
  local name="$1" port pf pid
  port="$(port_of "$name")"
  # Tear down whatever ssh is forwarding this slot's port — ours or a tunnel the
  # project's dev script started. NB: one ssh can bundle several slots' ports, so
  # stopping one bundled slot drops the others sharing that ssh too.
  [ -n "$port" ] && pkill -f "${port}:localhost:${port}" 2>/dev/null
  pf="$(pidfile "$name")"
  pid="$(cat "$pf" 2>/dev/null)"
  if [ -n "$pid" ]; then
    kill "$pid" 2>/dev/null
    # ssh can spawn a helper; sweep any stragglers in its group.
    pkill -P "$pid" 2>/dev/null
  fi
  rm -f "$pf"
  refresh_bar
}

case "${1:-list}" in
  list)
    registry | while IFS='|' read -r name group label detail _; do
      [ -n "$name" ] || continue
      if is_running "$name"; then st=on; else st=off; fi
      printf '%s|%s|%s|%s|%s\n' "$name" "$group" "$label" "$detail" "$st"
    done
    true
    ;;
  status)
    if is_running "${2:?name}"; then echo on; else echo off; exit 1; fi
    ;;
  start)  start_one "${2:?name}" ;;
  stop)   stop_one  "${2:?name}" ;;
  toggle)
    if is_running "${2:?name}"; then stop_one "$2"; else start_one "$2"; fi
    ;;
  stop-all)
    registry | while IFS='|' read -r name _; do [ -n "$name" ] && stop_one "$name"; done
    ;;
  open)
    shift
    ports="$(parse_ports "$@")"
    [ -n "$ports" ] || { echo "no valid ports in: $*" >&2; exit 1; }
    host="$(default_host)"
    [ -n "$host" ] || { echo "no ssh host — set PF_HOST or ~/.centinel-tunnel-host" >&2; exit 1; }
    first="$(printf '%s\n' "$ports" | head -1)"
    name="adhoc-$(printf '%s' "$ports" | tr '\n' '-' | sed 's/-$//')"
    label="$(printf '%s' "$ports" | paste -sd',' -)"
    cmd="exec \"\$HOME/scripts/pf.sh\" $host $(printf '%s' "$ports" | tr '\n' ' ')"
    touch "$ADHOC_CONF"
    grep -q "^${name}|" "$ADHOC_CONF" 2>/dev/null \
      || printf '%s|Custom|%s|:%s|%s\n' "$name" "$label" "$first" "$cmd" >> "$ADHOC_CONF"
    start_one "$name"
    ;;
  forget)   # stop an ad-hoc tunnel and drop it from the menu (no-op on fixed slots)
    name="${2:?name}"
    stop_one "$name"
    if [ -f "$ADHOC_CONF" ]; then
      grep -v "^${name}|" "$ADHOC_CONF" > "$ADHOC_CONF.tmp" 2>/dev/null ||:
      mv "$ADHOC_CONF.tmp" "$ADHOC_CONF" 2>/dev/null ||:
    fi
    refresh_bar
    ;;
  *) echo "usage: pf-ctl {list|status|start|stop|toggle|stop-all|open <ports>|forget <name>} [name]" >&2; exit 2 ;;
esac
