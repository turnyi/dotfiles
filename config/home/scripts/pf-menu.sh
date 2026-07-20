#!/usr/bin/env bash
# pf-menu — harpoon-style menu for the SSH port-forward slots (pf-ctl.sh), driven
# from tmux or a plain terminal, modelled on the ★ bookmarks menu. There is no
# search box; each row is numbered, so plain keys are controls.
#
# Two views, tab switches between them:
#
#   ⇄ tunnels   is a tunnel process forwarding this slot's port?
#               1-9 / enter  toggle that slot on/off
#   🌐 open      is the port actually ANSWERING right now? (a tunnel can be up
#               with nothing behind it; a local dev server needs no tunnel)
#               1-9 / enter  open http://localhost:PORT in the browser
#
#   tab  switch view      s  stop that slot      ^a  stop everything
#   j/k  move             d  drop an ad-hoc entry
#   +    open ad-hoc ports (prompt)              esc / q  close (silent)
#
#   pf-menu            picker in the current terminal
#   pf-menu --popup    open it in a centered tmux popup (bind a key to this)
#   pf-menu --float    open it in a floating terminal window (waybar click, WM bind)
#   pf-menu --list     emit the picker feed (used internally by fzf reload)
#   pf-menu --add      prompt for ports and open them (used internally by `+`)
#   pf-menu --view     print the current view name (used internally by the header)
#   pf-menu --flip     switch view (used internally by tab)
#   pf-menu --go       act on a row: toggle it, or open its URL (used internally)
set -uo pipefail

PF="$HOME/scripts/pf-ctl.sh"
SELF="$HOME/scripts/pf-menu.sh"
RUN_DIR="${XDG_RUNTIME_DIR:-$HOME/.cache}/pf"
VIEW_FILE="$RUN_DIR/menu-view"   # survives the fzf reloads, so tab can persist
mkdir -p "$RUN_DIR"

GREEN=$'\033[32m'; DIM=$'\033[90m'; BOLD=$'\033[1m'; NUM=$'\033[33m'
BLUE=$'\033[34m'; RST=$'\033[0m'

view() { case "$(cat "$VIEW_FILE" 2>/dev/null)" in open) echo open ;; *) echo tunnels ;; esac; }
flip() { if [ "$(view)" = tunnels ]; then echo open >"$VIEW_FILE"; else echo tunnels >"$VIEW_FILE"; fi; }

# Every local TCP port with a listener, one per line. This is the "open" test:
# it sees a forwarded port and a plain local dev server alike, which is the whole
# point of this view — what can I actually reach right now.
listening() {
  if command -v ss >/dev/null 2>&1; then
    ss -ltnH 2>/dev/null | awk '{print $4}' | sed 's/.*://'
  else # macOS / no iproute2
    lsof -nP -iTCP -sTCP:LISTEN 2>/dev/null | awk 'NR>1 {sub(/.*:/, "", $9); print $9}'
  fi | grep -E '^[0-9]+$' | sort -u
}

# Rows are: name \t display \t url. fzf shows only field 2 (--with-nth=2); the
# binds read field 1 to act on the slot and field 3 to open it.
feed() {
  local mode; mode=$(view)
  local -A live=()
  if [ "$mode" = open ]; then
    local p; while read -r p; do live[$p]=1; done < <(listening)
  fi

  local i=0 n name group label detail status port url on
  while IFS='|' read -r name group label detail status; do
    [ -n "$name" ] || continue
    i=$((i + 1)); [ "$i" -le 9 ] && n="$i" || n=' '
    port="${detail#:}"; port="${port// /}"
    url=""; [ -n "$port" ] && url="http://localhost:$port"

    if [ "$mode" = open ]; then
      # "on" here means the port answers, NOT that we started something.
      [ -n "$port" ] && [ -n "${live[$port]:-}" ] && on=1 || on=0
    else
      [ "$status" = "on" ] && on=1 || on=0
    fi

    if [ "$on" = 1 ]; then
      printf '%s\t%s%s%s %s●%s %s%-8s%s %-6s %s%s%s\t%s\n' \
        "$name" "$NUM" "$n" "$RST" "$GREEN" "$RST" "$BOLD" "$group" "$RST" "$label" \
        "$([ "$mode" = open ] && printf '%s' "$BLUE" || printf '%s' "$GREEN")" "$detail" "$RST" "$url"
    else
      printf '%s\t%s%s%s %s○  %-8s %-6s %s%s\t%s\n' \
        "$name" "$NUM" "$n" "$RST" "$DIM" "$group" "$label" "$detail" "$RST" "$url"
    fi
  done < <("$PF" list)
}

# What enter / 1-9 do depends on the view, so the binds delegate here rather than
# hard-coding an action fzf can't switch at runtime.
go() { # go <name> <url>
  local name="${1:-}" url="${2:-}"
  [ -n "$name" ] || return 0
  if [ "$(view)" = open ]; then
    [ -n "$url" ] || return 0
    if command -v xdg-open >/dev/null 2>&1; then xdg-open "$url" >/dev/null 2>&1 &
    elif command -v open >/dev/null 2>&1; then open "$url" >/dev/null 2>&1 &
    fi
  else
    "$PF" toggle "$name"
  fi
  return 0
}

header() {
  if [ "$(view)" = open ]; then
    printf '🌐 open  ·  tab: tunnels  ·  enter url · s stop · ^a all'
  else
    printf '⇄ tunnels  ·  tab: open  ·  enter toggle · + ports · ^a all'
  fi
}

# Prompt for a port spec and open it. ESC cancels.
add() {
  local spec
  spec=$(: | fzf --print-query --reverse --info=hidden --no-separator \
    --prompt='open ports ❯ ' \
    --header='e.g. 5555, 55510  8888-8889   ·   enter: open · esc: cancel')
  spec=$(printf '%s\n' "$spec" | head -1)
  [ -n "$spec" ] && "$PF" open $spec   # word-split intentionally: pf-ctl parses tokens
  return 0
}

menu() {
  local digitbinds=() i
  for i in 1 2 3 4 5 6 7 8 9; do
    digitbinds+=(--bind "$i:pos($i)+execute-silent($SELF --go {1} {3})+reload($SELF --list)")
  done
  feed | fzf --ansi --reverse --no-sort --no-input \
    --delimiter='\t' --with-nth=2 \
    --bind="start:transform-header($SELF --view-header)" \
    --bind='j:down,k:up,g:first,G:last' \
    "${digitbinds[@]}" \
    --bind="enter:execute-silent($SELF --go {1} {3})+reload($SELF --list)" \
    --bind="tab:execute-silent($SELF --flip)+reload($SELF --list)+transform-header($SELF --view-header)" \
    --bind="s:execute-silent($PF stop {1})+reload($SELF --list)" \
    --bind="d:execute-silent($PF forget {1})+reload($SELF --list)" \
    --bind="ctrl-a:execute-silent($PF stop-all)+reload($SELF --list)" \
    --bind="+:execute($SELF --add)+reload($SELF --list)" \
    --bind='esc:abort' \
    --bind='q:abort' >/dev/null
}

case "${1:-menu}" in
  --list)         feed ;;
  --add)          add ;;
  --view)         view ;;
  --view-header)  header ;;
  --flip)         flip ;;
  --go)           go "${2:-}" "${3:-}" ;;
  --menu|menu)    menu ;;
  --popup)        # fixed width, height sized to the slot count (like the ★ C-b popup)
                  n=$("$PF" list | grep -c .) || n=0
                  h=$((n + 6)); [ "$h" -lt 8 ] && h=8; [ "$h" -gt 24 ] && h=24
                  exec tmux display-popup -E -w 48 -h "$h" -T ' ⇄ ports ' \
                    -b rounded -S 'fg=#9ed072' -s 'bg=default' "$SELF --menu" ;;
  --float)        # Same menu, but standalone — for a waybar click or a WM keybind,
                  # where there's no tmux client to hang a popup off. The app-id is
                  # what the hyprland windowrule floats/centers (see hyprland.conf).
                  n=$("$PF" list | grep -c .) || n=0
                  h=$((n + 6)); [ "$h" -lt 8 ] && h=8; [ "$h" -gt 24 ] && h=24
                  exec kitty --class pf-menu -o "initial_window_width=48c" \
                    -o "initial_window_height=${h}c" -e "$SELF --menu" ;;
  -h|--help)      sed -n '2,24p' "$0" | sed 's/^# \{0,1\}//' ;;
  *)              echo "usage: pf-menu [--popup|--float|--menu|--list|--add]" >&2; exit 2 ;;
esac
