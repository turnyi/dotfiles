#!/usr/bin/env bash

# Shared account layout for every Google-backed eww widget.
#
# Each account owns a directory that doubles as its XDG_DATA_HOME, because
# gcalcli resolves its token through platformdirs and ignores --config-folder.
# That token is a pickle written by gcalcli itself; the Gmail token is JSON
# written by google-auth.sh. Adding an account means creating a directory, so
# no widget carries a hardcoded account list.
#
#   ~/.local/share/google-accounts/<account>/gcalcli/oauth
#   ~/.local/share/google-accounts/<account>/gmail-token.json
#
# Tokens live outside the dotfiles repo on purpose: ~/.config/eww is a symlink
# into it, so anything stored there would be committed.

GOOGLE_ACCOUNTS_DIR="${GOOGLE_ACCOUNTS_DIR:-$HOME/.local/share/google-accounts}"
GOOGLE_CLIENT_FILE="${GOOGLE_CLIENT_FILE:-$HOME/.config/google-accounts/client.json}"

google_accounts_list() {
  [ -d "$GOOGLE_ACCOUNTS_DIR" ] || return 0
  local dir
  for dir in "$GOOGLE_ACCOUNTS_DIR"/*/; do
    [ -d "$dir" ] || continue
    basename "$dir"
  done
}

google_account_dir() {
  echo "$GOOGLE_ACCOUNTS_DIR/$1"
}

google_account_has_calendar() {
  [ -f "$GOOGLE_ACCOUNTS_DIR/$1/gcalcli/oauth" ]
}

google_account_has_gmail() {
  [ -f "$GOOGLE_ACCOUNTS_DIR/$1/gmail-token.json" ]
}
