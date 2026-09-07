#!/usr/bin/env bash
set -euo pipefail

# Authenticates any number of Google accounts for the calendar and gmail
# widgets. Usage:
#
#   google-auth.sh add personal work startup
#   google-auth.sh list
#   google-auth.sh remove work
#
# Both flows need a terminal: gcalcli prompts on stdin, and the Gmail flow
# prints a URL. Without one this re-execs inside tmux rather than dying on
# EOFError, so it works from a script, a hotkey, or an eww button.

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=google-accounts.sh
source "$script_dir/google-accounts.sh"

tmux_session="google-auth"

require_tty() {
  [ -t 0 ] && return 0

  if ! command -v tmux &> /dev/null; then
    echo "No terminal on stdin and tmux is not installed." >&2
    echo "Run this from a terminal instead." >&2
    exit 1
  fi

  if tmux has-session -t "$tmux_session" 2> /dev/null; then
    echo "An auth session is already running. Attach with:" >&2
    echo "  tmux attach -t $tmux_session" >&2
    exit 1
  fi

  local quoted
  quoted=$(printf '%q ' "$0" "$@")
  # tmux filters the environment it hands a new session, so any override of
  # these has to be forwarded explicitly or the session silently uses defaults.
  tmux new-session -d -s "$tmux_session" \
    -e "GOOGLE_ACCOUNTS_DIR=$GOOGLE_ACCOUNTS_DIR" \
    -e "GOOGLE_CLIENT_FILE=$GOOGLE_CLIENT_FILE" \
    "$quoted; printf '\nDone. Press enter to close.'; read -r"

  echo "No terminal available, so the auth flow was started in tmux."
  echo "Attach to it and sign in:"
  echo
  echo "  tmux attach -t $tmux_session"
  exit 0
}

read_client() {
  if [ ! -f "$GOOGLE_CLIENT_FILE" ]; then
    cat >&2 <<EOF
No OAuth client at $GOOGLE_CLIENT_FILE

Create one (once, shared by every account):
  1. https://console.cloud.google.com -> create or pick a project
  2. APIs & Services -> Library -> enable "Google Calendar API" and "Gmail API"
  3. APIs & Services -> OAuth consent screen -> External,
     and add every account you plan to add here as a Test user
  4. Credentials -> Create Credentials -> OAuth client ID -> Desktop app
  5. Download the JSON and save it as:
       $GOOGLE_CLIENT_FILE
EOF
    exit 1
  fi

  client_id=$(python3 -c "
import json,sys
d=json.load(open(sys.argv[1]))
d=d.get('installed') or d.get('web') or d
print(d['client_id'])
" "$GOOGLE_CLIENT_FILE")

  client_secret=$(python3 -c "
import json,sys
d=json.load(open(sys.argv[1]))
d=d.get('installed') or d.get('web') or d
print(d['client_secret'])
" "$GOOGLE_CLIENT_FILE")
}

auth_calendar() {
  local account="$1"
  local account_dir
  account_dir=$(google_account_dir "$account")

  if google_account_has_calendar "$account"; then
    echo "  calendar: already authenticated"
    return 0
  fi

  mkdir -p "$account_dir/gcalcli"
  if XDG_DATA_HOME="$account_dir" gcalcli \
    --client-id "$client_id" --client-secret "$client_secret" list > /dev/null; then
    echo "  calendar: ok"
  else
    echo "  calendar: FAILED" >&2
    return 1
  fi
}

auth_gmail() {
  local account="$1"
  local account_dir
  account_dir=$(google_account_dir "$account")

  if google_account_has_gmail "$account"; then
    echo "  gmail: already authenticated"
    return 0
  fi

  mkdir -p "$account_dir"
  if python3 -c "
import json, os, sys
from google_auth_oauthlib.flow import InstalledAppFlow

client_file, token_file = sys.argv[1], sys.argv[2]
flow = InstalledAppFlow.from_client_secrets_file(
    client_file, ['https://www.googleapis.com/auth/gmail.readonly']
)
creds = flow.run_local_server(port=0)
with open(token_file, 'w') as f:
    f.write(creds.to_json())
os.chmod(token_file, 0o600)
" "$GOOGLE_CLIENT_FILE" "$account_dir/gmail-token.json"; then
    echo "  gmail: ok"
  else
    echo "  gmail: FAILED" >&2
    return 1
  fi
}

cmd_add() {
  [ $# -gt 0 ] || { echo "Usage: google-auth.sh add <account>..." >&2; exit 1; }
  require_tty add "$@"
  read_client

  local account
  for account in "$@"; do
    echo "==> $account (sign in as this account in the browser)"
    auth_calendar "$account" || true
    auth_gmail "$account" || true
  done

  echo
  cmd_list
}

cmd_list() {
  local accounts
  accounts=$(google_accounts_list)

  if [ -z "$accounts" ]; then
    echo "No accounts yet. Add one with: google-auth.sh add <name>"
    return 0
  fi

  printf '%-16s %-10s %s\n' "ACCOUNT" "CALENDAR" "GMAIL"
  local account cal mail
  while read -r account; do
    google_account_has_calendar "$account" && cal="yes" || cal="no"
    google_account_has_gmail "$account" && mail="yes" || mail="no"
    printf '%-16s %-10s %s\n' "$account" "$cal" "$mail"
  done <<< "$accounts"
}

cmd_remove() {
  [ $# -gt 0 ] || { echo "Usage: google-auth.sh remove <account>..." >&2; exit 1; }
  local account account_dir
  for account in "$@"; do
    account_dir=$(google_account_dir "$account")
    if [ -d "$account_dir" ]; then
      rm -rf "$account_dir"
      echo "removed $account"
    else
      echo "no such account: $account" >&2
    fi
  done
}

case "${1:-list}" in
  add)    shift; cmd_add "$@" ;;
  list)   cmd_list ;;
  remove) shift; cmd_remove "$@" ;;
  *)
    echo "Usage: google-auth.sh {add <account>... | list | remove <account>...}" >&2
    exit 1
    ;;
esac
