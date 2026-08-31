#!/usr/bin/env bash
# cal-menu — Google Calendar on the tmux top bar + a mission-control popup,
# modelled on pf-menu. Data comes from gcalcli (already authed via
# ~/.config/gcalcli/oauth); every reader goes through an on-disk cache because
# a gcalcli round-trip takes seconds and the status bar redraws every 5s.
#
#   cal-menu --segment   status-bar segment: the ongoing / next meeting with a
#                        countdown (reads the cache only; kicks a detached
#                        refresh when the cache is older than 5 min)
#   cal-menu --popup     mission control: this week's agenda in a centered
#                        tmux popup — j/k move, enter opens the meeting link,
#                        y copies it, r refetches, esc/q closes
#   cal-menu --refresh   fetch the agenda into the cache (also used internally)
#   cal-menu --auth NAME log a Google account in under this name; every named
#                        account's agenda is fetched and merged. Needs the
#                        shared OAuth client in ~/.config/gcalcli/oauth-client
#                        (json: {"client_id": …, "client_secret": …})
#   cal-menu --list      emit the fzf feed (used internally by reload)
#   cal-menu --go URL    open a row's link (used internally)
set -uo pipefail

SELF="$HOME/scripts/cal-menu.sh"
RUN_DIR="${XDG_RUNTIME_DIR:-$HOME/.cache}/gcal"
AGENDA="$RUN_DIR/agenda.tsv"
ERR_FLAG="$RUN_DIR/refresh-failed"
LOCK="$RUN_DIR/refresh.lock"
ACCT_DIR="$HOME/.config/gcalcli/accounts"
OAUTH_CLIENT="$HOME/.config/gcalcli/oauth-client"
MAX_AGE=300
mkdir -p "$RUN_DIR"

DIM="#7f849c"
TEXT="#cdd6f4"
PEACH="#fab387"
RED="#f38ba8"
GREEN="#a6e3a1"

ICON_CAL=$'\U000f00ed'
ICON_MEET=$'\U000f0919'
ICON_FREE=$'\U000f1055'

A_GREEN=$'\033[32m'; A_DIM=$'\033[90m'; A_BOLD=$'\033[1m'; A_BLUE=$'\033[34m'
A_YEL=$'\033[33m'; A_RED=$'\033[31m'; A_RST=$'\033[0m'

# One agenda fetch per account under ~/.config/gcalcli/accounts (or the plain
# default gcalcli config when none exist), merged and re-sorted by start time —
# gcalcli itself is single-account. A partial failure still publishes what
# succeeded, but keeps the error flag so the popup/segment can hint at it.
refresh() {
  exec 9>"$LOCK"
  flock -n 9 || return 0
  local tmp="$AGENDA.tmp" header="" ok=0 fail=0 f
  : >"$tmp.body"
  fetch_one() {
    if timeout 60 gcalcli "$@" --nocolor agenda --tsv \
        --details url --details conference \
        "$(date '+%Y-%m-%dT00:00')" "$(date -d '+7 days' '+%Y-%m-%d')" \
        >"$tmp.one" 2>/dev/null; then
      [ -n "$header" ] || header=$(head -1 "$tmp.one")
      tail -n +2 "$tmp.one" >>"$tmp.body"
      ok=$((ok + 1))
    else
      fail=$((fail + 1))
    fi
    rm -f "$tmp.one"
  }
  if ls -d "$ACCT_DIR"/*/ >/dev/null 2>&1; then
    for f in "$ACCT_DIR"/*/; do fetch_one --config-folder "$f"; done
  else
    fetch_one
  fi
  if ((ok > 0)); then
    { printf '%s\n' "$header"; sort -t$'\t' -k1,1 -k2,2 "$tmp.body"; } >"$AGENDA"
  fi
  rm -f "$tmp.body"
  if ((fail > 0)); then touch "$ERR_FLAG"; else rm -f "$ERR_FLAG"; fi
}

auth() {
  local name="${1:-}" cid csec folder
  if [ -z "$name" ]; then
    echo "usage: cal-menu --auth <account-name>   (e.g. --auth centinel)" >&2
    return 2
  fi
  cid=$(jq -r '.client_id // empty' "$OAUTH_CLIENT" 2>/dev/null)
  csec=$(jq -r '.client_secret // empty' "$OAUTH_CLIENT" 2>/dev/null)
  if [ -z "$cid" ] || [ -z "$csec" ]; then
    echo "No OAuth client found. Create a Desktop-app OAuth client in the" >&2
    echo "Google Cloud console and save it as $OAUTH_CLIENT:" >&2
    echo '  {"client_id": "…", "client_secret": "…"}' >&2
    return 1
  fi
  folder="$ACCT_DIR/$name"
  mkdir -p "$folder"
  # `y` feeds the ignore-and-refresh prompt on a re-auth; on a first auth
  # gcalcli never reads stdin (id/secret come from the flags).
  printf 'y\n' | gcalcli --config-folder "$folder" \
    --client-id "$cid" --client-secret "$csec" init || return 1
  "$SELF" --refresh
}

refresh_bg_if_stale() {
  local age=$((MAX_AGE + 1)) mtime
  mtime=$(stat -c %Y "$AGENDA" 2>/dev/null) && age=$(($(date +%s) - mtime))
  ((age > MAX_AGE)) || return 0
  ("$SELF" --refresh </dev/null >/dev/null 2>&1 &)
}

# Normalised events from the cached TSV, one per line:
#   start_epoch \t end_epoch \t allday(0/1) \t url \t title
# Columns are located by header name so a gcalcli upgrade reordering the TSV
# degrades to empty fields instead of scrambled ones. Link preference:
# conference uri (the actual meet/zoom room) > legacy hangout > the event page.
events() {
  [ -s "$AGENDA" ] || return 0
  gawk -F'\t' '
    NR == 1 { for (i = 1; i <= NF; i++) col[$i] = i; next }
    {
      sd = $col["start_date"]; st = $col["start_time"]
      ed = $col["end_date"];   et = $col["end_time"]
      if (sd == "") next
      url = $col["conference_uri"]
      if (url == "") url = $col["hangout_link"]
      if (url == "") url = $col["html_link"]
      allday = (st == "00:00" && et == "00:00" && ed > sd) ? 1 : 0
      s = sd " " st; e = ed " " et
      gsub(/[-:]/, " ", s); gsub(/[-:]/, " ", e)
      printf "%d\t%d\t%d\t%s\t%s\n", \
        mktime(s " 00"), mktime(e " 00"), allday, url, $col["title"]
    }' "$AGENDA"
}

segment() {
  refresh_bg_if_stale
  if [ ! -s "$AGENDA" ]; then
    [ -f "$ERR_FLAG" ] && printf '#[fg=%s]%s auth  ' "$RED" "$ICON_CAL"
    return 0
  fi
  local now line s e allday url title
  now=$(date +%s)
  while IFS=$'\t' read -r s e allday url title; do
    ((allday)) && continue
    ((e <= now)) && continue
    ((s > now + 36000)) && break
    local mins=$(((s - now + 59) / 60)) color when
    if ((s <= now)); then
      color=$GREEN; when="now"
    elif ((mins <= 5)); then
      color=$RED; when="${mins}m"
    elif ((mins <= 30)); then
      color=$PEACH; when="${mins}m"
    elif ((mins <= 480)); then
      color=$TEXT; when="$(date -d "@$s" '+%H:%M')"
    else
      color=$DIM; when="$(date -d "@$s" '+%a %H:%M')"
    fi
    ((${#title} > 24)) && title="${title:0:23}…"
    printf '#[fg=%s]%s %s %s#[fg=default]  ' "$color" "$ICON_MEET" "$title" "$when"
    return 0
  done < <(events)
  printf '#[fg=%s]%s#[fg=default]  ' "$DIM" "$ICON_FREE"
}

feed() {
  if [ ! -s "$AGENDA" ]; then
    if [ -f "$ERR_FLAG" ]; then
      printf -- '-\t%s⚠ calendar auth failed — run: cal-menu.sh --auth <name>%s\n' "$A_RED" "$A_RST"
    else
      printf -- '-\t%sfetching agenda… press r%s\n' "$A_DIM" "$A_RST"
    fi
    return 0
  fi
  local now today s e allday url title day link stamp
  now=$(date +%s); today=$(date +%Y-%m-%d)
  while IFS=$'\t' read -r s e allday url title; do
    if [ "$(date -d "@$s" +%Y-%m-%d)" = "$today" ]; then day="today "; else day=$(date -d "@$s" '+%a %d'); fi
    link=""; [ -n "$url" ] && link=" $A_BLUE$ICON_MEET$A_RST"
    if ((allday)); then stamp="all-day    "; else stamp="$(date -d "@$s" +%H:%M)–$(date -d "@$e" +%H:%M)"; fi
    if ((e <= now)) && ((allday == 0)); then
      printf '%s\t%s%-6s %s %s%s\n' "${url:--}" "$A_DIM" "$day" "$stamp" "$title" "$A_RST"
    elif ((s <= now)) && ((allday == 0)); then
      printf '%s\t%s%-6s%s %s%s● %s%s%s%s\n' "${url:--}" "$A_YEL" "$day" "$A_RST" "$stamp " "$A_GREEN" "$A_BOLD" "$title" "$A_RST" "$link"
    else
      printf '%s\t%s%-6s%s %s %s%s%s%s\n' "${url:--}" "$A_YEL" "$day" "$A_RST" "$stamp" "$A_BOLD" "$title" "$A_RST" "$link"
    fi
  done < <(events)
}

# First row that is not already over — where the cursor should land.
next_pos() {
  local now pos=0 s e allday _
  now=$(date +%s)
  while IFS=$'\t' read -r s e allday _; do
    pos=$((pos + 1))
    ((allday == 0 && e > now)) && { echo "$pos"; return 0; }
  done < <(events)
  echo 1
}

go() {
  local url="${1:-}"
  [ -n "$url" ] && [ "$url" != "-" ] || return 0
  if command -v xdg-open >/dev/null 2>&1; then xdg-open "$url" >/dev/null 2>&1 &
  elif command -v open >/dev/null 2>&1; then open "$url" >/dev/null 2>&1 &
  fi
  return 0
}

copy() {
  local url="${1:-}"
  [ -n "$url" ] && [ "$url" != "-" ] || return 0
  if command -v wl-copy >/dev/null 2>&1; then printf '%s' "$url" | wl-copy
  elif command -v pbcopy >/dev/null 2>&1; then printf '%s' "$url" | pbcopy
  fi
  return 0
}

menu() {
  refresh_bg_if_stale
  feed | fzf --ansi --reverse --no-sort --no-input \
    --delimiter='\t' --with-nth=2 \
    --footer='enter open link · y copy · r refetch · esc close' \
    --bind="start:pos($(next_pos))" \
    --bind='j:down,k:up,g:first,G:last' \
    --bind="enter:execute-silent($SELF --go {1})+abort" \
    --bind="o:execute-silent($SELF --go {1})+abort" \
    --bind="y:execute-silent($SELF --copy {1})" \
    --bind="r:execute-silent($SELF --refresh)+reload($SELF --list)" \
    --bind='esc:abort' \
    --bind='q:abort' >/dev/null
  # Same as pf-menu: esc/q (130) and an empty list (1) are normal exits, and
  # would otherwise make `display-popup -E` announce «…returned 130».
  local rc=$?
  case "$rc" in 0 | 1 | 130) return 0 ;; *) return "$rc" ;; esac
}

case "${1:-menu}" in
  --segment)   segment ;;
  --refresh)   refresh ;;
  --auth)      auth "${2:-}" ;;
  --list)      feed ;;
  --next-pos)  next_pos ;;
  --go)        go "${2:-}" ;;
  --copy)      copy "${2:-}" ;;
  --menu|menu) menu ;;
  --popup)
    n=$(events | grep -c .) || n=0
    h=$((n + 5)); [ "$h" -lt 10 ] && h=10; [ "$h" -gt 26 ] && h=26
    exec tmux display-popup -E -w 64 -h "$h" -T " $ICON_CAL agenda " \
      -b rounded -S "fg=$PEACH" -s 'bg=default' "$SELF --menu" ;;
  -h|--help)   sed -n '2,16p' "$0" | sed 's/^# \{0,1\}//' ;;
  *)           echo "usage: cal-menu [--popup|--menu|--segment|--refresh|--list]" >&2; exit 2 ;;
esac
