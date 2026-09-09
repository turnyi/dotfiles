#!/usr/bin/env bash
# cal-setup — one interactive pass that gets the tmux calendar bar working:
# creates the shared OAuth client record, signs in each Google account, then
# proves the agenda actually fetches. Companion to cal-menu.sh, which reads
# what this writes.
#
#   cal-setup.sh                 wizard: asks for accounts, signs them in
#   cal-setup.sh work personal   same, without the prompt
#   cal-setup.sh --list          which accounts exist and whether they fetch
#   cal-setup.sh --remove NAME   forget an account
#   cal-setup.sh --reset-client  re-enter the OAuth client id/secret
#
# The Cloud-console half cannot be scripted (Google has no API for creating an
# OAuth client), so that part is a guided copy-paste. Everything after it is
# automatic.
set -uo pipefail

ACCT_DIR="$HOME/.config/gcalcli/accounts"
OAUTH_CLIENT="$HOME/.config/gcalcli/oauth-client"
ICS_URLS="$HOME/.config/gcal-ics/urls"
CAL_MENU="$HOME/scripts/cal-menu.sh"
CONSOLE_URL="https://console.cloud.google.com/apis/credentials"
TMUX_SESSION="cal-setup"

B=$'\033[1m'; DIM=$'\033[90m'; GRN=$'\033[32m'; YEL=$'\033[33m'
RED=$'\033[31m'; RST=$'\033[0m'

say()  { printf '%s\n' "$*"; }

# Echoes one * per character. A plain `read -rs` is silent, which over ssh
# leaves no way to tell a paste that landed from one that did not.
read_masked() {
  local prompt="$1" __var="$2" out="" char got=0
  printf '%s' "$prompt"
  while IFS= read -rsn1 char; do
    got=1
    [ -z "$char" ] && break
    case "$char" in
      $'\177' | $'\b')
        [ -n "$out" ] && { out="${out%?}"; printf '\b \b'; }
        continue ;;
    esac
    out+="$char"
    printf '*'
  done
  printf '\n'
  printf -v "$__var" '%s' "$out"
  ((got)) || return 1
}
ok()   { printf '%s✓%s %s\n' "$GRN" "$RST" "$*"; }
warn() { printf '%s!%s %s\n' "$YEL" "$RST" "$*"; }
bad()  { printf '%s✗%s %s\n' "$RED" "$RST" "$*" >&2; }
head_() { printf '\n%s%s%s\n' "$B" "$*" "$RST"; }

require_deps() {
  local missing=()
  command -v gcalcli  &> /dev/null || missing+=("gcalcli")
  command -v jq       &> /dev/null || missing+=("jq")
  command -v python3  &> /dev/null || missing+=("python3")
  if ((${#missing[@]})); then
    bad "Missing: ${missing[*]}"
    say "  yay -S ${missing[*]}"
    exit 1
  fi
}

# gcalcli prompts on stdin and opens a browser, so a pipe or a tmux run-shell
# would die with EOFError. Re-exec into a session the user can attach to.
require_tty() {
  [ -t 0 ] && [ -t 1 ] && return 0
  if ! command -v tmux &> /dev/null; then
    bad "Needs a terminal (gcalcli prompts and opens a browser)."
    exit 1
  fi
  if tmux has-session -t "$TMUX_SESSION" 2> /dev/null; then
    warn "Setup already running. Attach with:  tmux attach -t $TMUX_SESSION"
    exit 1
  fi
  local quoted
  quoted=$(printf '%q ' "$0" "$@")
  tmux new-session -d -s "$TMUX_SESSION" \
    "$quoted; printf '\n[enter] to close '; read -r"
  say "Started in tmux (this shell has no terminal). Attach and sign in:"
  say
  say "  ${B}tmux attach -t $TMUX_SESSION${RST}"
  exit 0
}

client_ready() {
  [ -s "$OAUTH_CLIENT" ] || return 1
  local cid csec
  cid=$(jq -r '.client_id // empty'     "$OAUTH_CLIENT" 2> /dev/null)
  csec=$(jq -r '.client_secret // empty' "$OAUTH_CLIENT" 2> /dev/null)
  [ -n "$cid" ] && [ -n "$csec" ]
}

setup_client() {
  head_ "Step 1 — OAuth client (once, shared by every account)"
  cat <<EOF
Google has no API for this, so it is copy-paste. In the Cloud console:

  1. Create or pick a project
  2. APIs & Services -> Library -> enable ${B}Google Calendar API${RST}
  3. APIs & Services -> OAuth consent screen -> ${B}External${RST}
     Add every Google account you plan to use here as a ${B}Test user${RST},
     otherwise its sign-in is refused.
  4. Credentials -> Create Credentials -> OAuth client ID
     Application type: ${B}Desktop app${RST}   (a Web client rejects the
     loopback redirect gcalcli uses)
  5. Copy the client ID and client secret from the dialog

EOF
  if command -v xdg-open &> /dev/null; then
    read -r -p "Open the console in your browser? [Y/n] " open_it
    case "$open_it" in
      [Nn]*) : ;;
      *) xdg-open "$CONSOLE_URL" > /dev/null 2>&1 & ;;
    esac
  else
    say "  $CONSOLE_URL"
  fi

  local cid csec
  while :; do
    say
    read -r -p "Client ID: " cid || { bad "No input (EOF)."; exit 1; }
    cid="${cid//[[:space:]]/}"
    [ -n "$cid" ] || { warn "Cannot be empty."; continue; }
    case "$cid" in
      *.apps.googleusercontent.com) break ;;
      *) warn "That does not look like a client ID (should end in .apps.googleusercontent.com)." ;;
    esac
  done
  while :; do
    read_masked "Client secret: " csec || { bad "No input (EOF)."; exit 1; }
    csec="${csec//[[:space:]]/}"
    # A clipboard holding both values pastes as one string with no visible
    # feedback, so strip a leading client id rather than storing the pair.
    case "$csec" in
      "$cid"*) csec="${csec#"$cid"}"; warn "Stripped a client ID that came in with the secret." ;;
    esac
    [ -n "$csec" ] || { warn "Cannot be empty."; continue; }
    case "$csec" in
      GOCSPX-*) ;;
      *) warn "Secrets normally start with GOCSPX-; got ${#csec} chars starting '${csec:0:4}'."
         read -r -p "  Use it anyway? [y/N] " yn
         [[ "$yn" == [Yy]* ]] || continue ;;
    esac
    say "  Got ${#csec} chars: ${csec:0:7}$(printf '%*s' $((${#csec} - 7)) '' | tr ' ' '*')"
    read -r -p "  Correct? [Y/n] " yn
    [[ "$yn" == [Nn]* ]] || break
  done

  mkdir -p "$(dirname "$OAUTH_CLIENT")"
  jq -n --arg id "$cid" --arg secret "$csec" \
    '{client_id: $id, client_secret: $secret}' > "$OAUTH_CLIENT"
  chmod 600 "$OAUTH_CLIENT"
  ok "Saved $OAUTH_CLIENT"
}

account_authed() { [ -f "$ACCT_DIR/$1/gcalcli/oauth" ]; }

auth_account() {
  local name="$1" cid csec folder
  folder="$ACCT_DIR/$name"

  if account_authed "$name"; then
    ok "$name — already signed in"
    return 0
  fi

  cid=$(jq -r '.client_id'     "$OAUTH_CLIENT")
  csec=$(jq -r '.client_secret' "$OAUTH_CLIENT")
  mkdir -p "$folder"

  say
  say "${B}$name${RST} — a browser window will open; sign in as this account."
  say "${DIM}An 'unverified app' warning is expected: Advanced -> Go to (unsafe).${RST}"

  # XDG_DATA_HOME is what actually selects the account: gcalcli resolves its
  # token through platformdirs and ignores --config-folder entirely.
  # 'y' answers the ignore-and-refresh prompt when re-authing.
  if printf 'y\n' | XDG_DATA_HOME="$folder" gcalcli \
      --client-id "$cid" --client-secret "$csec" init; then
    if account_authed "$name"; then
      ok "$name — signed in"
      return 0
    fi
    bad "$name — gcalcli exited cleanly but wrote no token"
    return 1
  fi
  bad "$name — sign-in failed"
  return 1
}

# A token can exist and still not fetch (revoked grant, Calendar API not
# enabled), so check the thing the status bar actually depends on.
account_event_count() {
  local name="$1" out
  out=$(timeout 60 env XDG_DATA_HOME="$ACCT_DIR/$name" gcalcli --nocolor agenda --tsv \
    "$(date '+%Y-%m-%dT00:00')" "$(date -d '+7 days' '+%Y-%m-%d')" \
    < /dev/null 2>/dev/null) || return 1
  printf '%s' "$out" | tail -n +2 | grep -c . || true
}

cmd_list() {
  local found=0 name count
  head_ "Accounts"
  if [ -d "$ACCT_DIR" ]; then
    for dir in "$ACCT_DIR"/*/; do
      [ -d "$dir" ] || continue
      found=1
      name=$(basename "$dir")
      if ! account_authed "$name"; then
        printf '  %-16s %s\n' "$name" "no token"
      elif count=$(account_event_count "$name"); then
        printf '  %-16s %s events in the next 7 days\n' "$name" "$count"
      else
        printf '  %-16s %sfetch failed%s\n' "$name" "$RED" "$RST"
      fi
    done
  fi
  ((found)) || say "  none yet"

  if [ -s "$ICS_URLS" ] && grep -qE '^[^#]*https?://' "$ICS_URLS"; then
    warn "$ICS_URLS has URLs in it, and cal-menu prefers that source."
    say "  Comment those lines out to use these OAuth accounts instead."
  fi
}

cmd_remove() {
  local name="$1"
  if [ -d "$ACCT_DIR/$name" ]; then
    rm -rf "${ACCT_DIR:?}/$name"
    ok "removed $name"
  else
    bad "no such account: $name"
  fi
}

main() {
  require_deps

  case "${1:-}" in
    --list)   cmd_list; exit 0 ;;
    --remove) shift; [ $# -gt 0 ] || { bad "usage: cal-setup.sh --remove NAME"; exit 1; }
              for a in "$@"; do cmd_remove "$a"; done; exit 0 ;;
    --reset-client) rm -f "$OAUTH_CLIENT"; shift ;;
    -h|--help) sed -n '2,16p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
  esac

  require_tty "$@"

  say "${B}Calendar setup${RST} — signs Google accounts into the tmux status bar."

  client_ready || setup_client
  client_ready || { bad "Still no usable OAuth client."; exit 1; }
  ok "OAuth client ready"

  local -a accounts=("$@")
  if ((${#accounts[@]} == 0)); then
    head_ "Step 2 — accounts"
    say "Pick a short name per Google account (personal, work, startup...)."
    say "${DIM}Names are labels for you; the actual address comes from the login.${RST}"
    say
    read -r -p "Account names, space separated: " -a accounts
  fi
  if ((${#accounts[@]} == 0)); then
    bad "No accounts given."
    exit 1
  fi

  head_ "Step 3 — sign in"
  local failed=0 name
  for name in "${accounts[@]}"; do
    auth_account "$name" || failed=$((failed + 1))
  done

  head_ "Step 4 — fetch the agenda"
  if [ -s "$ICS_URLS" ] && grep -qE '^[^#]*https?://' "$ICS_URLS"; then
    warn "$ICS_URLS has URLs, which cal-menu prefers over these accounts."
    say "  Comment them out if you want the accounts you just added to be used."
  fi
  if [ -x "$CAL_MENU" ]; then
    "$CAL_MENU" --refresh
    ok "cache refreshed"
  else
    warn "cal-menu.sh not found at $CAL_MENU; skipped refresh"
  fi

  cmd_list

  say
  if ((failed)); then
    bad "$failed account(s) failed. Re-run to retry just those."
    exit 1
  fi
  ok "Done. Press C-e in tmux for the agenda popup."
}

main "$@"
