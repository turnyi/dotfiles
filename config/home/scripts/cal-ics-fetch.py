#!/usr/bin/env python3
# Fetches Google Calendar "secret iCal address" URLs and prints the coming
# week's events in the exact TSV shape `gcalcli agenda --tsv --details url
# --details conference` emits, so cal-menu.sh can read either source from the
# same cache. No OAuth: the secret URL is the credential, one per calendar,
# any number of accounts. Recurrence is expanded with dateutil (RRULE +
# EXDATE + RECURRENCE-ID overrides) because an ICS export carries the rule,
# not the instances.
import re
import sys
import urllib.request
from datetime import date, datetime, time, timedelta
from pathlib import Path

from dateutil import rrule, tz

URLS_FILE = Path.home() / '.config' / 'gcal-ics' / 'urls'
WINDOW_DAYS = 7
LOCAL_TZ = tz.tzlocal()
URL_RE = re.compile(
    r'https?://(?:[\w.-]*zoom\.us|meet\.google\.com|teams\.microsoft\.com'
    r'|[\w.-]*webex\.com)/[^\s<>"\']+'
)

HEADER = ('start_date\tstart_time\tend_date\tend_time\thtml_link\t'
          'hangout_link\tconference_entry_point_type\tconference_uri\ttitle')


def unfold(text):
    return re.sub(r'\r?\n[ \t]', '', text).splitlines()


def parse_events(text):
    events, cur = [], None
    for line in unfold(text):
        if line == 'BEGIN:VEVENT':
            cur = {}
        elif line == 'END:VEVENT':
            if cur is not None:
                events.append(cur)
            cur = None
        elif cur is not None and ':' in line:
            key, value = line.split(':', 1)
            name, _, params = key.partition(';')
            cur.setdefault(name.upper(), []).append((params, value))
    return events


def prop(ev, name):
    vals = ev.get(name)
    return vals[0] if vals else (None, None)


def parse_dt(params, value):
    params = dict(p.split('=', 1) for p in (params or '').split(';') if '=' in p)
    if params.get('VALUE') == 'DATE' or re.fullmatch(r'\d{8}', value):
        d = datetime.strptime(value, '%Y%m%d')
        return d.replace(tzinfo=LOCAL_TZ), True
    if value.endswith('Z'):
        dt = datetime.strptime(value, '%Y%m%dT%H%M%SZ').replace(tzinfo=tz.UTC)
    else:
        zone = tz.gettz(params['TZID']) if 'TZID' in params else LOCAL_TZ
        dt = datetime.strptime(value, '%Y%m%dT%H%M%S').replace(tzinfo=zone)
    return dt, False


def conference_url(ev):
    _, conf = prop(ev, 'X-GOOGLE-CONFERENCE')
    if conf:
        return conf
    for field in ('LOCATION', 'DESCRIPTION'):
        _, val = prop(ev, field)
        if val:
            m = URL_RE.search(val.replace('\\n', '\n').replace('\\,', ','))
            if m:
                return m.group(0)
    return ''


def clean_title(ev):
    _, summary = prop(ev, 'SUMMARY')
    summary = (summary or '(no title)')
    return re.sub(r'\\([,;nN])', lambda m: ' ' if m.group(1) in 'nN' else m.group(1),
                  summary).replace('\t', ' ').strip()


def instances(ev, win_start, win_end):
    params, value = prop(ev, 'DTSTART')
    if value is None:
        return
    start, all_day = parse_dt(params, value)

    end_params, end_value = prop(ev, 'DTEND')
    if end_value is not None:
        end, _ = parse_dt(end_params, end_value)
        duration = end - start
    else:
        _, dur = prop(ev, 'DURATION')
        m = re.fullmatch(r'P(?:(\d+)D)?(?:T(?:(\d+)H)?(?:(\d+)M)?(?:(\d+)S)?)?',
                         dur or '')
        d, h, mi, s = ((int(x) if x else 0) for x in (m.groups() if m else (0,) * 4))
        duration = timedelta(days=d, hours=h, minutes=mi, seconds=s)

    _, rule_value = prop(ev, 'RRULE')
    if rule_value is None:
        if start < win_end and start + duration > win_start:
            yield start, start + duration, all_day
        return

    exdates = set()
    for ex_params, ex_value in ev.get('EXDATE', []):
        for chunk in ex_value.split(','):
            exdates.add(parse_dt(ex_params, chunk)[0])
    try:
        rule = rrule.rrulestr(rule_value, dtstart=start)
        starts = rule.between(win_start - duration, win_end, inc=True)
    except (ValueError, TypeError):
        return
    for s in starts:
        if s not in exdates:
            yield s, s + duration, all_day


def rows_from_ics(text, win_start, win_end):
    events = parse_events(text)
    overridden = set()
    for ev in events:
        rid = prop(ev, 'RECURRENCE-ID')
        if rid[1] is not None:
            _, uid = prop(ev, 'UID')
            overridden.add((uid, parse_dt(*rid)[0]))

    for ev in events:
        _, uid = prop(ev, 'UID')
        _, status = prop(ev, 'STATUS')
        if status == 'CANCELLED':
            continue
        is_override = prop(ev, 'RECURRENCE-ID')[1] is not None
        for start, end, all_day in instances(ev, win_start, win_end):
            if not is_override and (uid, start) in overridden:
                continue
            s, e = start.astimezone(LOCAL_TZ), end.astimezone(LOCAL_TZ)
            yield (s, '\t'.join((
                s.strftime('%Y-%m-%d'), s.strftime('%H:%M'),
                e.strftime('%Y-%m-%d'), e.strftime('%H:%M'),
                '', '', 'video' if conference_url(ev) else '',
                conference_url(ev), clean_title(ev))))


def main():
    if not URLS_FILE.is_file():
        print(f'no urls file at {URLS_FILE}', file=sys.stderr)
        return 1
    urls = [line.split()[-1] for line in URLS_FILE.read_text().splitlines()
            if line.strip() and not line.lstrip().startswith('#')]
    if not urls:
        print(f'{URLS_FILE} is empty', file=sys.stderr)
        return 1

    win_start = datetime.combine(date.today(), time.min, LOCAL_TZ)
    win_end = win_start + timedelta(days=WINDOW_DAYS)
    rows, failures = [], 0
    for url in urls:
        try:
            req = urllib.request.Request(url, headers={'User-Agent': 'cal-menu'})
            with urllib.request.urlopen(req, timeout=30) as resp:
                text = resp.read().decode('utf-8', 'replace')
            rows.extend(rows_from_ics(text, win_start, win_end))
        except Exception as exc:
            print(f'fetch failed: {exc}', file=sys.stderr)
            failures += 1

    if failures == len(urls):
        return 1
    print(HEADER)
    for _, row in sorted(rows, key=lambda r: r[0]):
        print(row)
    return 2 if failures else 0


if __name__ == '__main__':
    sys.exit(main())
