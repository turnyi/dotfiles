#!/usr/bin/env python3
# Calendar actions cal-menu cannot express through gcalcli: sending an RSVP and
# reading who else is coming. Runs against the same per-account tokens
# cal-setup.sh wrote, picked by the account name the agenda row carries.
#
#   cal-api.py rsvp <account> <calendar> <event_id> accepted|declined|tentative
#   cal-api.py info <account> <calendar> <event_id>

import os
import pickle
import sys
from pathlib import Path

ACCOUNTS = Path.home() / '.config' / 'gcalcli' / 'accounts'

RESET = '\033[0m'
BOLD = '\033[1m'
DIM = '\033[90m'
GREEN = '\033[32m'
RED = '\033[31m'
YEL = '\033[33m'
BLUE = '\033[34m'

MARK = {
    'accepted': (GREEN, '✓'),
    'declined': (RED, '✗'),
    'tentative': (YEL, '?'),
    'needsAction': (DIM, '·'),
}


def service_for(account):
    token = ACCOUNTS / account / 'gcalcli' / 'oauth'
    if not token.exists():
        die(f'no token for account {account!r} — run cal-setup.sh {account}')
    from googleapiclient.discovery import build
    with open(token, 'rb') as fh:
        creds = pickle.load(fh)
    return build('calendar', 'v3', credentials=creds, cache_discovery=False)


def die(msg):
    print(f'{RED}{msg}{RESET}', file=sys.stderr)
    sys.exit(1)


# The agenda carries a calendar *name*, which for a primary calendar is the
# address and works as an id. Anything else falls back to 'primary' rather than
# failing, since that is where a personally-invited event lives.
def resolve_calendar(svc, calendar):
    if calendar and '@' in calendar:
        return calendar
    return 'primary'


def fetch(svc, calendar, event_id):
    from googleapiclient.errors import HttpError
    for cal in (resolve_calendar(svc, calendar), 'primary'):
        try:
            return cal, svc.events().get(calendarId=cal, eventId=event_id).execute()
        except HttpError as e:
            if e.resp.status in (403, 404):
                continue
            die(f'calendar api error: {e}')
    die('event not found on this account')


def cmd_rsvp(account, calendar, event_id, response):
    if response not in ('accepted', 'declined', 'tentative'):
        die(f'bad response {response!r}')
    svc = service_for(account)
    cal, event = fetch(svc, calendar, event_id)

    attendees = event.get('attendees') or []
    me = next((a for a in attendees if a.get('self')), None)
    if me is None:
        die('you are not on this event\'s guest list — nothing to RSVP to')

    me['responseStatus'] = response
    from googleapiclient.errors import HttpError
    try:
        svc.events().patch(
            calendarId=cal, eventId=event_id,
            body={'attendees': attendees}, sendUpdates='all',
        ).execute()
    except HttpError as e:
        die(f'could not send RSVP: {e}')

    colour, mark = MARK[response]
    print(f'{colour}{mark} {response}{RESET}  {event.get("summary", "(untitled)")}')


def cmd_info(account, calendar, event_id):
    svc = service_for(account)
    _, event = fetch(svc, calendar, event_id)

    print(f'{BOLD}{event.get("summary", "(untitled)")}{RESET}')
    when = event.get('start', {})
    start = when.get('dateTime') or when.get('date') or '?'
    print(f'{DIM}{start}{RESET}   {DIM}account:{RESET} {account}')

    if event.get('location'):
        print(f'{DIM}where:{RESET} {event["location"]}')

    link = (event.get('hangoutLink')
            or (event.get('conferenceData', {}) or {}).get('entryPoints', [{}])[0].get('uri'))
    if link:
        print(f'{DIM}join :{RESET} {BLUE}{link}{RESET}')

    organizer = (event.get('organizer') or {}).get('email')
    if organizer:
        print(f'{DIM}host :{RESET} {organizer}')

    attendees = event.get('attendees') or []
    if not attendees:
        print(f'\n{DIM}no guests{RESET}')
    else:
        tally = {}
        for a in attendees:
            tally[a.get('responseStatus', 'needsAction')] = \
                tally.get(a.get('responseStatus', 'needsAction'), 0) + 1
        summary = '  '.join(
            f'{MARK[k][0]}{MARK[k][1]} {v}{RESET}'
            for k, v in sorted(tally.items()) if k in MARK
        )
        print(f'\n{BOLD}guests ({len(attendees)}){RESET}   {summary}')
        for a in sorted(attendees, key=lambda x: x.get('responseStatus', '')):
            status = a.get('responseStatus', 'needsAction')
            colour, mark = MARK.get(status, (DIM, '·'))
            name = a.get('displayName') or a.get('email', '?')
            tag = f' {DIM}(you){RESET}' if a.get('self') else ''
            org = f' {DIM}(host){RESET}' if a.get('organizer') else ''
            print(f'  {colour}{mark}{RESET} {name}{tag}{org}')

    desc = (event.get('description') or '').strip()
    if desc:
        print(f'\n{BOLD}notes{RESET}')
        for line in desc.splitlines()[:10]:
            print(f'  {line[:100]}')


def main():
    if len(sys.argv) < 5:
        print(__doc__ or 'usage: cal-api.py {rsvp|info} <account> <calendar> <event_id> [response]',
              file=sys.stderr)
        sys.exit(2)
    cmd, account, calendar, event_id = sys.argv[1:5]
    if cmd == 'rsvp':
        if len(sys.argv) < 6:
            die('rsvp needs a response')
        cmd_rsvp(account, calendar, event_id, sys.argv[5])
    elif cmd == 'info':
        cmd_info(account, calendar, event_id)
    else:
        die(f'unknown command {cmd!r}')


if __name__ == '__main__':
    main()
