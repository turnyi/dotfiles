#!/usr/bin/env python3

"""
Google Calendar subscription script
Adds a calendar to your calendar list by email
"""

import os
import sys
from google.oauth2.credentials import Credentials
from google.auth.transport.requests import Request
from googleapiclient.discovery import build
from google_auth_oauthlib.flow import InstalledAppFlow

SCOPES = ['https://www.googleapis.com/auth/calendar']
CREDS_FILE = os.path.expanduser('~/.config/eww/gmail-credentials.json')
TOKEN_FILE = os.path.expanduser('~/.config/gcalcli/oauth')

def get_credentials():
    creds = None
    
    # Check if we have a token
    if os.path.exists(TOKEN_FILE):
        try:
            creds = Credentials.from_authorized_user_file(TOKEN_FILE, SCOPES)
        except:
            pass
    
    # If no valid credentials, authenticate
    if not creds or not creds.valid:
        if creds and creds.expired and creds.refresh_token:
            creds.refresh(Request())
        else:
            if not os.path.exists(CREDS_FILE):
                print(f"ERROR: Credentials file not found at {CREDS_FILE}")
                print("Using the same credentials as Gmail widget")
                return None
            
            flow = InstalledAppFlow.from_client_secrets_file(CREDS_FILE, SCOPES)
            creds = flow.run_local_server(port=0)
        
        # Save credentials
        os.makedirs(os.path.dirname(TOKEN_FILE), exist_ok=True)
        with open(TOKEN_FILE, 'w') as token:
            token.write(creds.to_json())
    
    return creds

def subscribe_to_calendar(calendar_email):
    creds = get_credentials()
    if not creds:
        return False
    
    try:
        service = build('calendar', 'v3', credentials=creds)
        
        # Check if calendar exists and is accessible
        print(f"Searching for calendar: {calendar_email}")
        
        # Try to get the calendar
        try:
            calendar = service.calendars().get(calendarId=calendar_email).execute()
            print(f"✓ Found calendar: {calendar.get('summary', calendar_email)}")
        except Exception as e:
            print(f"❌ Cannot access calendar {calendar_email}")
            print(f"   Error: {e}")
            print("")
            print("Possible reasons:")
            print("1. The calendar owner needs to share it with you")
            print("2. The email address is incorrect")
            print("3. The calendar doesn't exist")
            return False
        
        # Add to calendar list
        calendar_list_entry = {
            'id': calendar_email
        }
        
        try:
            created = service.calendarList().insert(body=calendar_list_entry).execute()
            print(f"✓ Successfully subscribed to {calendar_email}")
            print(f"  Calendar ID: {created['id']}")
            return True
        except Exception as e:
            if 'duplicate' in str(e).lower() or 'already' in str(e).lower():
                print(f"✓ Already subscribed to {calendar_email}")
                return True
            else:
                print(f"❌ Error subscribing: {e}")
                return False
                
    except Exception as e:
        print(f"❌ Error: {e}")
        return False

def list_calendars():
    creds = get_credentials()
    if not creds:
        return
    
    try:
        service = build('calendar', 'v3', credentials=creds)
        calendars = service.calendarList().list().execute()
        
        print("\n=== Your Calendars ===")
        for calendar in calendars.get('items', []):
            access = calendar.get('accessRole', 'unknown')
            summary = calendar.get('summary', 'Unnamed')
            cal_id = calendar.get('id', '')
            print(f"  [{access}] {summary}")
            if cal_id != summary:
                print(f"           {cal_id}")
        print("")
        
    except Exception as e:
        print(f"❌ Error listing calendars: {e}")

if __name__ == '__main__':
    if len(sys.argv) < 2:
        print("Usage:")
        print(f"  {sys.argv[0]} <calendar-email>        # Subscribe to a calendar")
        print(f"  {sys.argv[0]} list                     # List all calendars")
        print("")
        print("Examples:")
        print(f"  {sys.argv[0]} joaquin.meerhoff@opti-task.com")
        print(f"  {sys.argv[0]} list")
        sys.exit(1)
    
    if sys.argv[1] == 'list':
        list_calendars()
    else:
        calendar_email = sys.argv[1]
        success = subscribe_to_calendar(calendar_email)
        if success:
            print("")
            list_calendars()
        sys.exit(0 if success else 1)
