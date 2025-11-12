#!/usr/bin/env bash

# Gmail checker script for eww
# Uses Gmail API to check unread emails

# For now, using a simple approach with google-api-python-client
# You'll need to set up OAuth credentials

# Check if we have credentials
# Use absolute path to ensure it works when called from eww
CREDS_FILE="$HOME/.config/eww/gmail-credentials.json"
TOKEN_FILE="$HOME/.config/eww/gmail-token.json"

if [ ! -f "$TOKEN_FILE" ]; then
  # No token yet, return placeholder
  echo '[{"from":"Setup Required","subject":"Run gmail authentication","time":"--","unread":true}]'
  exit 0
fi

# Use Python to fetch emails
python3 << 'EOF'
import os
import json
from datetime import datetime
try:
    from google.auth.transport.requests import Request
    from google.oauth2.credentials import Credentials
    from googleapiclient.discovery import build
except ImportError:
    print('[{"from":"Error","subject":"Install: pip install google-auth google-auth-oauthlib google-auth-httplib2 google-api-python-client","time":"--","unread":true}]')
    exit(0)

TOKEN_FILE = os.path.expanduser('~/.config/eww/gmail-token.json')
CREDS_FILE = os.path.expanduser('~/.config/eww/gmail-credentials.json')

creds = None
if os.path.exists(TOKEN_FILE):
    creds = Credentials.from_authorized_user_file(TOKEN_FILE, ['https://www.googleapis.com/auth/gmail.readonly'])

if not creds or not creds.valid:
    if creds and creds.expired and creds.refresh_token:
        creds.refresh(Request())
        with open(TOKEN_FILE, 'w') as token:
            token.write(creds.to_json())
    else:
        print('[{"from":"Auth Required","subject":"Please run: python3 ~/.config/eww/scripts/gmail-auth.py","time":"--","unread":true}]')
        exit(0)

try:
    service = build('gmail', 'v1', credentials=creds)
    results = service.users().messages().list(userId='me', labelIds=['INBOX'], q='is:unread', maxResults=5).execute()
    messages = results.get('messages', [])
    
    emails = []
    for msg in messages:
        msg_data = service.users().messages().get(userId='me', id=msg['id'], format='metadata', metadataHeaders=['From', 'Subject', 'Date']).execute()
        headers = {h['name']: h['value'] for h in msg_data['payload']['headers']}
        
        from_email = headers.get('From', 'Unknown')
        # Extract name from email
        if '<' in from_email:
            from_name = from_email.split('<')[0].strip().strip('"')
        else:
            from_name = from_email
        
        subject = headers.get('Subject', 'No Subject')
        date_str = headers.get('Date', '')
        
        # Parse date (simplified)
        try:
            time_display = datetime.strptime(date_str.split('(')[0].strip(), '%a, %d %b %Y %H:%M:%S %z').strftime('%H:%M')
        except:
            time_display = '--'
        
        emails.append({
            'from': from_name[:30],
            'subject': subject[:50],
            'time': time_display,
            'unread': True
        })
    
    print(json.dumps(emails))
except Exception as e:
    print('[{"from":"Error","subject":"' + str(e)[:50] + '","time":"--","unread":true}]')
EOF
