#!/usr/bin/env bash
set -euo pipefail

# Authenticates each Google account into its own XDG_DATA_HOME. gcalcli resolves
# its token through platformdirs and ignores --config-folder, so a separate data
# home per account is the only way to hold more than one token.
#
# Needs a real terminal: gcalcli prompts on stdin and opens a browser.

accounts_base="$HOME/.local/share/gcalcli-accounts"
accounts=("personal" "work" "startup")

client_id="${GCALCLI_CLIENT_ID:-}"
client_secret="${GCALCLI_CLIENT_SECRET:-}"

if [ -z "$client_id" ] || [ -z "$client_secret" ]; then
  echo "Set GCALCLI_CLIENT_ID and GCALCLI_CLIENT_SECRET first." >&2
  echo "Create a Desktop app OAuth client at https://console.cloud.google.com" >&2
  echo "with the Google Calendar API enabled." >&2
  exit 1
fi

for account in "${accounts[@]}"; do
  account_data="$accounts_base/$account"

  if [ -f "$account_data/gcalcli/oauth" ]; then
    echo "==> $account: already authenticated, skipping"
    continue
  fi

  echo "==> $account: opening browser, sign in as your $account account"
  mkdir -p "$account_data/gcalcli"

  if XDG_DATA_HOME="$account_data" gcalcli \
    --client-id "$client_id" --client-secret "$client_secret" list; then
    echo "==> $account: ok"
  else
    echo "==> $account: FAILED" >&2
  fi
done

echo
echo "Authenticated accounts:"
for account in "${accounts[@]}"; do
  if [ -f "$accounts_base/$account/gcalcli/oauth" ]; then
    echo "  $account: yes"
  else
    echo "  $account: no"
  fi
done
