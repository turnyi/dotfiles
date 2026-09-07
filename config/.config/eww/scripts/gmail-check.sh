#!/usr/bin/env bash

# Unread mail across every account added by google-auth.sh.

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=google-accounts.sh
source "$script_dir/google-accounts.sh"

max_emails=5

accounts=""
while read -r account; do
  [ -n "$account" ] || continue
  google_account_has_gmail "$account" || continue
  accounts+="$account"$'\n'
done <<< "$(google_accounts_list)"

if [ -z "$accounts" ]; then
  echo '[{"from":"Setup Required","subject":"Run: google-auth.sh add <account>","time":"--","unread":true}]'
  exit 0
fi

GOOGLE_ACCOUNTS_DIR="$GOOGLE_ACCOUNTS_DIR" \
MAX_EMAILS="$max_emails" \
ACCOUNTS="$accounts" \
python3 << 'EOF'
import json
import os
import sys
from datetime import datetime, timezone

try:
    from google.auth.transport.requests import Request
    from google.oauth2.credentials import Credentials
    from googleapiclient.discovery import build
except ImportError:
    print('[{"from":"Error","subject":"pip install google-auth google-auth-oauthlib google-api-python-client","time":"--","unread":true}]')
    sys.exit(0)

SCOPES = ['https://www.googleapis.com/auth/gmail.readonly']
accounts_dir = os.environ['GOOGLE_ACCOUNTS_DIR']
max_emails = int(os.environ['MAX_EMAILS'])
accounts = [a for a in os.environ['ACCOUNTS'].splitlines() if a]

# Distinct hue per account so the widget can tell them apart, matching the
# calendar widget's palette.
colors = ['#7aa2f7', '#bb9af7', '#73daca', '#e0af68', '#f7768e', '#9aa5ce']


def load_creds(token_file):
    creds = Credentials.from_authorized_user_file(token_file, SCOPES)
    if creds and creds.expired and creds.refresh_token:
        creds.refresh(Request())
        with open(token_file, 'w') as f:
            f.write(creds.to_json())
    return creds if creds and creds.valid else None


def sender_name(value):
    if '<' in value:
        name = value.split('<')[0].strip().strip('"')
        if name:
            return name
        return value.split('<')[1].rstrip('>')
    return value


def relative_time(internal_ms):
    then = datetime.fromtimestamp(int(internal_ms) / 1000, tz=timezone.utc)
    delta = datetime.now(timezone.utc) - then
    minutes = int(delta.total_seconds() // 60)
    if minutes < 1:
        return 'now'
    if minutes < 60:
        return f'{minutes}m'
    hours = minutes // 60
    if hours < 24:
        return f'{hours}h'
    return f'{hours // 24}d'


emails = []
errors = []

for index, account in enumerate(accounts):
    token_file = os.path.join(accounts_dir, account, 'gmail-token.json')
    try:
        creds = load_creds(token_file)
        if not creds:
            errors.append(account)
            continue

        service = build('gmail', 'v1', credentials=creds, cache_discovery=False)
        listing = service.users().messages().list(
            userId='me', labelIds=['INBOX'], q='is:unread',
            maxResults=max_emails,
        ).execute()

        for msg in listing.get('messages', []):
            data = service.users().messages().get(
                userId='me', id=msg['id'], format='metadata',
                metadataHeaders=['From', 'Subject'],
            ).execute()
            headers = {h['name']: h['value'] for h in data['payload']['headers']}
            emails.append({
                'from': sender_name(headers.get('From', 'Unknown')),
                'subject': headers.get('Subject', '(no subject)'),
                'time': relative_time(data['internalDate']),
                'account': account,
                'color': colors[index % len(colors)],
                'unread': True,
                '_sort': int(data['internalDate']),
            })
    except Exception:
        errors.append(account)

if not emails and errors:
    label = ', '.join(errors)
    print(json.dumps([{
        'from': 'Auth Required',
        'subject': f'Re-run: google-auth.sh add {label}',
        'time': '--',
        'unread': True,
    }]))
    sys.exit(0)

emails.sort(key=lambda e: e['_sort'], reverse=True)
for e in emails:
    del e['_sort']

print(json.dumps(emails[:max_emails]))
EOF
