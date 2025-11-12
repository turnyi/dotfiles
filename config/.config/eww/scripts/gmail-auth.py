#!/usr/bin/env python3

"""
Gmail OAuth authentication setup script
Run this once to authenticate with Gmail API
"""

import os
from google_auth_oauthlib.flow import InstalledAppFlow
from google.auth.transport.requests import Request
from google.oauth2.credentials import Credentials

SCOPES = ['https://www.googleapis.com/auth/gmail.readonly']
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
CONFIG_DIR = os.path.dirname(SCRIPT_DIR)
TOKEN_FILE = os.path.join(CONFIG_DIR, 'gmail-token.json')
CREDS_FILE = os.path.join(CONFIG_DIR, 'gmail-credentials.json')

def main():
    creds = None
    
    if os.path.exists(TOKEN_FILE):
        creds = Credentials.from_authorized_user_file(TOKEN_FILE, SCOPES)
    
    if not creds or not creds.valid:
        if creds and creds.expired and creds.refresh_token:
            creds.refresh(Request())
        else:
            if not os.path.exists(CREDS_FILE):
                print("ERROR: Credentials file not found!")
                print(f"Please download OAuth credentials from Google Cloud Console")
                print(f"and save to: {CREDS_FILE}")
                print("\nSteps:")
                print("1. Go to: https://console.cloud.google.com/apis/credentials")
                print("2. Create OAuth 2.0 Client ID (Desktop app)")
                print("3. Download JSON and save as gmail-credentials.json")
                return
            
            flow = InstalledAppFlow.from_client_secrets_file(CREDS_FILE, SCOPES)
            creds = flow.run_local_server(port=0)
        
        with open(TOKEN_FILE, 'w') as token:
            token.write(creds.to_json())
    
    print(f"✓ Authentication successful!")
    print(f"Token saved to: {TOKEN_FILE}")

if __name__ == '__main__':
    main()
