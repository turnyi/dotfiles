#!/usr/bin/env bash
# pf-menu — harpoon-style on/off menu for the SSH port-forward slots (pf-ctl.sh),
# driven from tmux or a plain terminal, modelled on the ★ bookmarks menu. There
# is no search box; each row is numbered, so plain keys are controls:
#
#   1-9 / enter   toggle that slot on/off        j / k / ↑ ↓   move
#   +             open ad-hoc ports (prompt)      d             drop an ad-hoc entry
#   ^a            stop everything                 esc / q       close
#
#   pf-menu            picker in the current terminal
#   pf-menu --popup    open it in a centered tmux popup (bind a key to this)
#   pf-menu --list     emit the picker feed (used internally by fzf reload)
#   pf-menu --add      prompt for ports and open them (used internally by `+`)
#   pf-menu --bye      farewell line printed on esc (used internally)
set -uo pipefail

PF="$HOME/scripts/pf-ctl.sh"
SELF="$HOME/scripts/pf-menu.sh"

GREEN=$'\033[32m'; DIM=$'\033[90m'; BOLD=$'\033[1m'; NUM=$'\033[33m'; RST=$'\033[0m'

# One row per slot: a hidden name field (for the toggle), then a 1-9 index and
# the colored, aligned display (dot · project · slot · port). The index matches
# the key you press, so you can see which button is which.
feed() {
  local i=0 n
  "$PF" list | while IFS='|' read -r name group label detail status; do
    [ -n "$name" ] || continue
    i=$((i + 1)); [ "$i" -le 9 ] && n="$i" || n=' '
    if [ "$status" = "on" ]; then
      printf '%s\t%s%s%s %s●%s %s%-8s%s %-6s %s%s%s\n' \
        "$name" "$NUM" "$n" "$RST" "$GREEN" "$RST" "$BOLD" "$group" "$RST" "$label" "$GREEN" "$detail" "$RST"
    else
      printf '%s\t%s%s%s %s○  %-8s %-6s %s%s\n' \
        "$name" "$NUM" "$n" "$RST" "$DIM" "$group" "$label" "$detail" "$RST"
    fi
  done
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

# Shown briefly in the popup when you press esc, then it closes.
bye() {
  local n; n=$("$PF" list | grep -c '|on$') || n=0
  printf '\n  ⇄ %s forward(s) active — closing…\n' "$n"
  sleep 0.6
}

menu() {
  local digitbinds=() i
  for i in 1 2 3 4 5 6 7 8 9; do
    digitbinds+=(--bind "$i:pos($i)+execute-silent($PF toggle {1})+reload($SELF --list)")
  done
  feed | fzf --ansi --reverse --no-sort --no-input \
    --delimiter='\t' --with-nth=2 \
    --header='+ open · ^a stop all' \
    --bind='j:down,k:up,g:first,G:last' \
    "${digitbinds[@]}" \
    --bind="enter:execute-silent($PF toggle {1})+reload($SELF --list)" \
    --bind="d:execute-silent($PF forget {1})+reload($SELF --list)" \
    --bind="ctrl-a:execute-silent($PF stop-all)+reload($SELF --list)" \
    --bind="+:execute($SELF --add)+reload($SELF --list)" \
    --bind="esc:execute($SELF --bye)+abort" \
    --bind='q:abort' >/dev/null
}

case "${1:-menu}" in
  --list)      feed ;;
  --add)       add ;;
  --bye)       bye ;;
  --menu|menu) menu ;;
  --popup)     # fixed width, height sized to the slot count (like the ★ C-b popup)
               n=$("$PF" list | grep -c .) || n=0
               h=$((n + 6)); [ "$h" -lt 8 ] && h=8; [ "$h" -gt 24 ] && h=24
               exec tmux display-popup -E -w 37 -h "$h" -T ' ⇄ ports ' \
                 -b rounded -S 'fg=#9ed072' -s 'bg=default' "$SELF --menu" ;;
  -h|--help)   sed -n '2,15p' "$0" | sed 's/^# \{0,1\}//' ;;
  *)           echo "usage: pf-menu [--popup|--menu|--list|--add]" >&2; exit 2 ;;
esac
