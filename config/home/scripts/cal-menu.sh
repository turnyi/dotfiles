#!/usr/bin/env bash
# cal-menu — Google Calendar on the tmux top bar + a mission-control popup,
# modelled on pf-menu. Data comes from gcalcli (already authed via
# ~/.config/gcalcli/oauth); every reader goes through an on-disk cache because
# a gcalcli round-trip takes seconds and the status bar redraws every 5s.
#
#   cal-menu --segment   status-bar segment: the ongoing meeting, or the next one
#                        once it is 30 min away, with a countdown (reads the
#                        cache only; kicks a detached refresh when the cache
#                        is older than 5 min)
#   cal-menu --waybar    the same meeting as waybar JSON (empty when none)
#   cal-menu --join      open the link of the meeting the bar is showing
#   cal-menu --popup     mission control: this week's agenda in a centered
#                        tmux popup — j/k move, enter opens the meeting link,
#                        y copies it, g/n RSVP going / not going, i shows the
#                        guest list, r refetches, esc/q closes. g used to mean
#                        "first"; that moved to H, because g now writes.
#   cal-menu --refresh   fetch the agenda into the cache (also used internally)
#
# Calendar source, simplest first: paste each calendar's "Secret address in
# iCal format" (Google Calendar settings) into ~/.config/gcal-ics/urls, one
# per line — no OAuth, multiple accounts just work. Only without that file
# does refresh fall back to gcalcli, where:
#   cal-menu --auth NAME logs a Google account in under this name; every named
#                        account's agenda is fetched and merged. Needs the
#                        shared OAuth client in ~/.config/gcalcli/oauth-client
#                        (json: {"client_id": …, "client_secret": …})
#   cal-menu --list      emit the fzf feed (used internally by reload)
#   cal-menu --go URL    open a row's link (used internally)
#
# ~/.config/gcal/hidden holds one calendar-name substring per line (case
# insensitive, # comments allowed); matching calendars are left out of both
# the bar and the popup. Needs the gcalcli source — the ics feed carries no
# calendar name.
set -uo pipefail

SELF="$HOME/scripts/cal-menu.sh"
RUN_DIR="${XDG_RUNTIME_DIR:-$HOME/.cache}/gcal"
AGENDA="$RUN_DIR/agenda.tsv"
ERR_FLAG="$RUN_DIR/refresh-failed"
LOCK="$RUN_DIR/refresh.lock"
ICS_URLS="$HOME/.config/gcal-ics/urls"
HIDE_FILE="$HOME/.config/gcal/hidden"
ACCT_DIR="$HOME/.config/gcalcli/accounts"
OAUTH_CLIENT="$HOME/.config/gcalcli/oauth-client"
MAX_AGE=300
# How long a finished event stays listed. Keeping the last hour means a meeting
# that just ended is still reachable for its link; older ones are noise.
PAST_GRACE=3600
LOOKAHEAD=1800
mkdir -p "$RUN_DIR"

DIM="#7f8490"
PEACH="#f39660"
RED="#fc5d7c"
GREEN="#9ed072"

ICON_CAL=$'\U000f00ed'
ICON_MEET=$'\U000f0919'
ICON_FREE=$'\U000f1055'

A_GREEN=$'\033[32m'; A_DIM=$'\033[90m'; A_BOLD=$'\033[1m'; A_BLUE=$'\033[34m'
A_YEL=$'\033[33m'; A_RED=$'\033[31m'; A_RST=$'\033[0m'

# Preferred source: secret-iCal URLs in ~/.config/gcal-ics/urls (no OAuth, any
# number of accounts) via cal-ics-fetch.py, which emits the same TSV gcalcli
# would. Fallback when that file is absent: one gcalcli fetch per account under
# ~/.config/gcalcli/accounts (or the plain default token), merged and
# re-sorted — gcalcli itself is single-account. A partial failure still
# publishes what succeeded, but keeps the error flag for the popup/segment.
refresh() {
  exec 9>"$LOCK"
  flock -n 9 || return 0
  local tmp="$AGENDA.tmp" header="" ok=0 fail=0 f
  # Test for an actual URL, not just a non-empty file: a comments-only urls
  # file would otherwise win over the OAuth accounts and fetch nothing.
  if grep -qE '^[^#]*https?://' "$ICS_URLS" 2> /dev/null; then
    python3 "$HOME/scripts/cal-ics-fetch.py" >"$tmp" 2>/dev/null
    case $? in
      0) mv "$tmp" "$AGENDA"; rm -f "$ERR_FLAG" ;;
      2) mv "$tmp" "$AGENDA"; touch "$ERR_FLAG" ;;
      *) rm -f "$tmp"; touch "$ERR_FLAG" ;;
    esac
    return 0
  fi
  : >"$tmp.body"
  fetch_one() {
    # gcalcli resolves its token through platformdirs and ignores
    # --config-folder, so XDG_DATA_HOME is the only thing that selects an
    # account; passing a config folder silently reuses one shared token.
    local data_home="${1:-}" account="${2:-}"
    local -a env_prefix=()
    [ -n "$data_home" ] && env_prefix=(env "XDG_DATA_HOME=$data_home")
    if timeout 60 "${env_prefix[@]}" gcalcli --nocolor agenda --tsv \
        --details url --details conference --details calendar --details id \
        "$(date '+%Y-%m-%dT00:00')" "$(date -d '+7 days' '+%Y-%m-%d')" \
        >"$tmp.one" 2>/dev/null; then
      # gcalcli cannot say which account a row came from, but RSVP and the
      # guest list have to run as that account, so tag every row here.
      [ -n "$header" ] || header="$(head -1 "$tmp.one")	account"
      tail -n +2 "$tmp.one" | sed "s/\$/\t$account/" >>"$tmp.body"
      ok=$((ok + 1))
    else
      fail=$((fail + 1))
    fi
    rm -f "$tmp.one"
  }
  if ls -d "$ACCT_DIR"/*/ >/dev/null 2>&1; then
    for f in "$ACCT_DIR"/*/; do fetch_one "$f" "$(basename "$f")"; done
  else
    fetch_one "" default
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
  printf 'y\n' | XDG_DATA_HOME="$folder" gcalcli \
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
#   start_epoch \t end_epoch \t allday(0/1) \t url \t account \t calendar \t
#   event_id \t title
# Absent fields are "-" rather than empty: bash read collapses runs of tabs
# (tab is IFS whitespace), so a blank would shift every later field.
# Columns are located by header name so a gcalcli upgrade reordering the TSV
# degrades to empty fields instead of scrambled ones. Link preference:
# conference uri (the actual meet/zoom room) > legacy hangout > the event page.
#
# Two passes of noise get dropped here. Calendars whose name matches a line in
# ~/.config/gcal/hidden are skipped, which is how a partner's or a colleague's
# shared calendar stays out of the bar. Then identical events are collapsed:
# when two signed-in accounts are both invited to the same meeting each
# account's agenda carries it, so it would otherwise appear once per account.
# The copy carrying a join link wins, since only the invited account may have
# the conference details.
events() {
  [ -s "$AGENDA" ] || return 0
  gawk -F'\t' -v hidefile="$HIDE_FILE" \
       -v cutoff="$(($(date +%s) - PAST_GRACE))" '
    BEGIN {
      nh = 0
      while ((getline line < hidefile) > 0) {
        sub(/#.*/, "", line)
        gsub(/^[ \t]+|[ \t]+$/, "", line)
        if (line != "") hide[++nh] = tolower(line)
      }
    }
    NR == 1 { for (i = 1; i <= NF; i++) col[$i] = i; next }
    {
      sd = $col["start_date"]; st = $col["start_time"]
      ed = $col["end_date"];   et = $col["end_time"]
      if (sd == "") next

      # Guarded: the ics fetcher emits no calendar column, and an unset index
      # would resolve to $0 and match every hide pattern against the row.
      cal = ("calendar" in col) ? $col["calendar"] : ""
      if (cal != "") {
        lc = tolower(cal)
        for (i = 1; i <= nh; i++) if (index(lc, hide[i])) next
      }

      # rank drives both the link preference and which duplicate survives:
      # a real meeting room beats the event page, which beats nothing.
      url = $col["conference_uri"]; rank = 2
      if (url == "") { url = $col["hangout_link"]; rank = 2 }
      if (url == "") { url = $col["html_link"];    rank = 1 }
      # "-" = no link: bash read collapses runs of tabs (tab is IFS
      # whitespace), so an empty field would shift the title into url.
      if (url == "") { url = "-"; rank = 0 }
      allday = (st == "00:00" && et == "00:00" && ed > sd) ? 1 : 0
      s = sd " " st; e = ed " " et
      gsub(/[-:]/, " ", s); gsub(/[-:]/, " ", e)
      se = mktime(s " 00"); ee = mktime(e " 00")
      if (ee < cutoff) next

      acct = ("account" in col) ? $col["account"] : ""
      evid = ("id" in col) ? $col["id"] : ""
      if (acct == "") acct = "-"
      if (cal == "")  cal = "-"
      if (evid == "") evid = "-"

      key = se "\t" ee "\t" $col["title"]
      line = se "\t" ee "\t" allday "\t" url "\t" acct "\t" cal "\t" evid \
             "\t" $col["title"]
      if (!(key in best)) { ord[++n] = key; best[key] = line; brank[key] = rank }
      else if (rank > brank[key]) { best[key] = line; brank[key] = rank }
    }
    END { for (i = 1; i <= n; i++) print best[ord[i]] }' "$AGENDA"
}

# Prints "state<TAB>countdown<TAB>title<TAB>url" for the ongoing meeting, or the
# next one once it is within LOOKAHEAD; prints nothing otherwise.
upcoming() {
  local now s e allday url acct cal evid title
  now=$(date +%s)
  while IFS=$'\t' read -r s e allday url acct cal evid title; do
    ((allday)) && continue
    ((e <= now)) && continue
    ((s > now + LOOKAHEAD)) && return 0
    local mins=$(((s - now + 59) / 60))
    if ((s <= now)); then
      printf 'now\tnow\t%s\t%s\n' "$title" "$url"
    elif ((mins <= 5)); then
      printf 'imminent\t%sm\t%s\t%s\n' "$mins" "$title" "$url"
    else
      printf 'soon\t%sm\t%s\t%s\n' "$mins" "$title" "$url"
    fi
    return 0
  done < <(events | sort -t $'\t' -k1,1n)
}

segment() {
  refresh_bg_if_stale
  if [ ! -s "$AGENDA" ]; then
    [ -f "$ERR_FLAG" ] && printf '#[fg=%s]%s auth  ' "$RED" "$ICON_CAL"
    return 0
  fi
  local state when title color
  IFS=$'\t' read -r state when title _ <<<"$(upcoming)"
  if [ -z "$state" ]; then
    printf '#[fg=%s]%s#[fg=default]  ' "$DIM" "$ICON_FREE"
    return 0
  fi
  case "$state" in
    now) color=$GREEN ;;
    imminent) color=$RED ;;
    *) color=$PEACH ;;
  esac
  ((${#title} > 24)) && title="${title:0:23}…"
  printf '#[fg=%s]%s %s %s#[fg=default]  ' "$color" "$ICON_MEET" "$title" "$when"
}

waybar_segment() {
  refresh_bg_if_stale
  if [ ! -s "$AGENDA" ]; then
    if [ -f "$ERR_FLAG" ]; then
      jq -cn --arg t "$ICON_CAL auth" \
        '{text: $t, tooltip: "calendar fetch failed", class: "error"}'
    else
      jq -cn '{text: ""}'
    fi
    return 0
  fi
  local state when title url short
  IFS=$'\t' read -r state when title url <<<"$(upcoming)"
  if [ -z "$state" ]; then
    jq -cn '{text: ""}'
    return 0
  fi
  short=$title
  ((${#short} > 32)) && short="${short:0:31}…"
  jq -cn --arg icon "$ICON_MEET" --arg short "$short" --arg title "$title" \
    --arg when "$when" --arg state "$state" --arg url "$url" '
    def markup: gsub("&"; "&amp;") | gsub("<"; "&lt;") | gsub(">"; "&gt;");
    {
      text: "\($icon)  \($short | markup)  \($when)",
      tooltip: (($title | markup) + (if $url != "" and $url != "-" then "\n\nclick: join" else "" end)),
      class: $state
    }'
}

join() {
  local url
  IFS=$'\t' read -r _ _ _ url <<<"$(upcoming)"
  go "$url"
}

feed() {
  if [ ! -s "$AGENDA" ]; then
    if [ -f "$ERR_FLAG" ]; then
      printf -- '-\t%s⚠ calendar fetch failed — check ~/.config/gcal-ics/urls%s\t-\t-\t-\n' "$A_RED" "$A_RST"
    else
      printf -- '-\t%sfetching agenda… press r%s\t-\t-\t-\n' "$A_DIM" "$A_RST"
    fi
    return 0
  fi
  local now today s e allday url acct cal evid title day link stamp meta
  now=$(date +%s); today=$(date +%Y-%m-%d)
  while IFS=$'\t' read -r s e allday url acct cal evid title; do
    # Fields 3-5 are the handle g/n/i need; --with-nth=2 keeps them off screen.
    meta="$acct	$cal	$evid"
    if [ "$(date -d "@$s" +%Y-%m-%d)" = "$today" ]; then day="today "; else day=$(date -d "@$s" '+%a %d'); fi
    link=""; [ "$url" != "-" ] && link=" $A_BLUE$ICON_MEET$A_RST"
    if ((allday)); then stamp="all-day    "; else stamp="$(date -d "@$s" +%H:%M)–$(date -d "@$e" +%H:%M)"; fi
    if ((e <= now)) && ((allday == 0)); then
      printf '%s\t%s%-6s %s %s%s\t%s\n' "${url:--}" "$A_DIM" "$day" "$stamp" "$title" "$A_RST" "$meta"
    elif ((s <= now)) && ((allday == 0)); then
      printf '%s\t%s%-6s%s %s%s● %s%s%s%s\t%s\n' "${url:--}" "$A_YEL" "$day" "$A_RST" "$stamp " "$A_GREEN" "$A_BOLD" "$title" "$A_RST" "$link" "$meta"
    else
      printf '%s\t%s%-6s%s %s %s%s%s%s\t%s\n' "${url:--}" "$A_YEL" "$day" "$A_RST" "$stamp" "$A_BOLD" "$title" "$A_RST" "$link" "$meta"
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

# With no display there is no browser to hand the link to, and xdg-open still
# exits 0 after falling through to text browsers that are not installed — so
# enter looked like a no-op over ssh. Copy instead: the link crosses to the
# local machine over OSC 52, which is the only route that actually works from
# a remote host.
go() {
  local url="${1:-}"
  [ -n "$url" ] && [ "$url" != "-" ] || return 0

  if [ -n "${WAYLAND_DISPLAY:-}" ] || [ -n "${DISPLAY:-}" ]; then
    if command -v xdg-open > /dev/null 2>&1; then
      xdg-open "$url" > /dev/null 2>&1 &
      return 0
    elif command -v open > /dev/null 2>&1; then
      open "$url" > /dev/null 2>&1 &
      return 0
    fi
  fi

  copy "$url" quiet
  [ -n "${TMUX:-}" ] && tmux display-message "no browser here — copied: $url"
  return 0
}

# tmux first, and not merely as a fallback: over ssh the wayland/X helpers
# either fail (no WAYLAND_DISPLAY in the session) or land in the *server's*
# clipboard, which is not the one the user pastes from. `load-buffer -w` hands
# the text to the outer terminal over OSC 52, so it reaches the local machine.
# Needs `set-clipboard on|external`, so say so rather than failing silently.
copy() {
  local url="${1:-}" quiet="${2:-}"
  [ -n "$url" ] && [ "$url" != "-" ] || return 0

  if [ -n "${TMUX:-}" ] && command -v tmux > /dev/null 2>&1; then
    printf '%s' "$url" | tmux load-buffer -w - 2> /dev/null \
      || printf '%s' "$url" | tmux load-buffer -
    [ -n "$quiet" ] && return 0
    case "$(tmux show -gv set-clipboard 2> /dev/null)" in
      on | external) tmux display-message "copied: $url" ;;
      *) tmux display-message "copied to tmux buffer (set-clipboard is off)" ;;
    esac
    return 0
  fi

  if [ -n "${WAYLAND_DISPLAY:-}" ] && command -v wl-copy > /dev/null 2>&1; then
    printf '%s' "$url" | wl-copy
  elif [ -n "${DISPLAY:-}" ] && command -v xclip > /dev/null 2>&1; then
    printf '%s' "$url" | xclip -selection clipboard
  elif [ -n "${DISPLAY:-}" ] && command -v xsel > /dev/null 2>&1; then
    printf '%s' "$url" | xsel --clipboard --input
  elif command -v pbcopy > /dev/null 2>&1; then
    printf '%s' "$url" | pbcopy
  fi
  return 0
}

CAL_API="$HOME/scripts/cal-api.py"

# Rows the agenda could not tag (the ics source carries no ids) come through as
# "-", so refuse rather than calling the api with junk.
rsvp() {
  local acct="${1:-}" cal="${2:-}" evid="${3:-}" response="${4:-}"
  if [ "$acct" = "-" ] || [ "$evid" = "-" ] || [ -z "$evid" ]; then
    [ -n "${TMUX:-}" ] && tmux display-message "no event id on this row — RSVP needs the gcalcli source"
    return 0
  fi
  local out
  if out=$(python3 "$CAL_API" rsvp "$acct" "$cal" "$evid" "$response" 2>&1); then
    [ -n "${TMUX:-}" ] && tmux display-message "$(printf '%s' "$out" | sed 's/\x1b\[[0-9;]*m//g' | head -1)"
  else
    [ -n "${TMUX:-}" ] && tmux display-message "RSVP failed: $(printf '%s' "$out" | sed 's/\x1b\[[0-9;]*m//g' | head -1)"
  fi
  return 0
}

info() {
  local acct="${1:-}" cal="${2:-}" evid="${3:-}"
  if [ "$acct" = "-" ] || [ "$evid" = "-" ] || [ -z "$evid" ]; then
    printf '%sno event details on this row — needs the gcalcli source%s\n' "$A_DIM" "$A_RST"
  else
    python3 "$CAL_API" info "$acct" "$cal" "$evid" 2>&1
  fi
  printf '\n%s[enter] back%s ' "$A_DIM" "$A_RST"
  read -r _
  return 0
}

menu() {
  refresh_bg_if_stale
  feed | fzf --ansi --reverse --no-sort --no-input \
    --delimiter='\t' --with-nth=2 \
    --footer='enter open · y copy · g going · n not · i info · r refetch · esc' \
    --bind="start:pos($(next_pos))" \
    --bind='j:down,k:up,H:first,G:last' \
    --bind="enter:execute-silent($SELF --go {1})+abort" \
    --bind="o:execute-silent($SELF --go {1})+abort" \
    --bind="y:execute-silent($SELF --copy {1})" \
    --bind="g:execute-silent($SELF --rsvp {3} {4} {5} accepted)" \
    --bind="n:execute-silent($SELF --rsvp {3} {4} {5} declined)" \
    --bind="i:execute($SELF --info {3} {4} {5})" \
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
  --waybar)    waybar_segment ;;
  --join)      join ;;
  --refresh)   refresh ;;
  --auth)      auth "${2:-}" ;;
  --list)      feed ;;
  --next-pos)  next_pos ;;
  --go)        go "${2:-}" ;;
  --copy)      copy "${2:-}" ;;
  --rsvp)      rsvp "${2:-}" "${3:-}" "${4:-}" "${5:-}" ;;
  --info)      info "${2:-}" "${3:-}" "${4:-}" ;;
  --menu|menu) menu ;;
  --popup)
    n=$(events | grep -c .) || n=0
    # fzf draws n rows plus a blank, a rule and the footer, and the popup's
    # two border rows sit outside that: h = n + 6 leaves one spare line so a
    # redraw cannot scroll the titled top border away.
    h=$((n + 6)); [ "$h" -lt 10 ] && h=10; [ "$h" -gt 26 ] && h=26
    ch=$(tmux display-message -p '#{client_height}' 2>/dev/null || echo 0)
    [ "$ch" -gt 4 ] && [ "$h" -gt $((ch - 2)) ] && h=$((ch - 2))
    exec tmux display-popup -E -w 64 -h "$h" -T " $ICON_CAL agenda " \
      -b rounded -S "fg=$PEACH" -s 'bg=default' "$SELF --menu" ;;
  -h|--help)   sed -n '2,16p' "$0" | sed 's/^# \{0,1\}//' ;;
  *)           echo "usage: cal-menu [--popup|--menu|--segment|--refresh|--list]" >&2; exit 2 ;;
esac
