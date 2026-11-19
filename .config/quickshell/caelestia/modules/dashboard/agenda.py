#!/usr/bin/python3
"""Print the events from last month to three months ahead from private ICS feeds as JSON for the dashboard agenda.

Feeds are read from ~/.local/share/caelestia/agenda-calendars, kept out of git: either a file with one ICS URL
per line, or a directory of .ics files.
The last successful result is cached so the agenda still shows when offline.
"""

import json
import re
import sys
import urllib.parse
import urllib.request
from datetime import date, datetime, time, timedelta
from pathlib import Path

import icalendar
import recurring_ical_events

FEEDS_FILE = Path.home() / ".local/share/caelestia/agenda-calendars"
CACHE_FILE = Path.home() / ".cache/caelestia/agenda.json"
MEETING_HOSTS = ("meet.google.com", "zoom.us", "teams.microsoft.com", "teams.live.com")
URL_PATTERN = re.compile(r"https?://[^\s<>\"'\\]+")


def feed_urls() -> list[str]:
    if FEEDS_FILE.is_dir():
        return [path.as_uri() for path in sorted(FEEDS_FILE.glob("*.ics"))]
    if not FEEDS_FILE.exists():
        return []
    lines = (line.strip() for line in FEEDS_FILE.read_text().splitlines())
    return [line for line in lines if line and not line.startswith("#")]


def is_meeting(url: str) -> bool:
    host = urllib.parse.urlparse(url).hostname or ""
    return any(host == known or host.endswith("." + known) for known in MEETING_HOSTS)


def meeting_link(event) -> str | None:
    candidates = [event.get("URL"), event.get("X-GOOGLE-CONFERENCE"), event.get("LOCATION"), event.get("DESCRIPTION")]
    for text in filter(None, map(str, filter(None, candidates))):
        for url in URL_PATTERN.findall(text):
            if is_meeting(url):
                return url
    return None


def local_datetime(value) -> datetime:
    if isinstance(value, datetime):
        return value.astimezone() if value.tzinfo else value.replace(tzinfo=None).astimezone()
    return datetime.combine(value, time()).astimezone()


def declined_by_owner(event, owner: str) -> bool:
    attendees = event.get("ATTENDEE") or []
    if not isinstance(attendees, list):
        attendees = [attendees]
    return any(
        str(attendee).lower().removeprefix("mailto:") == owner and attendee.params.get("PARTSTAT") == "DECLINED"
        for attendee in attendees
    )


def feed_events(url: str, window_start: datetime, window_end: datetime) -> list[dict]:
    with urllib.request.urlopen(url, timeout=15) as response:
        calendar = icalendar.Calendar.from_ical(response.read())
    owner = str(calendar.get("X-WR-CALNAME", "")).lower()
    events = []
    for event in recurring_ical_events.of(calendar).between(window_start, window_end):
        if event.get("STATUS") == "CANCELLED" or declined_by_owner(event, owner):
            continue
        start = event.decoded("DTSTART")
        end = event.decoded("DTEND") if "DTEND" in event else start + event.decoded("DURATION", timedelta())
        events.append({
            "title": str(event.get("SUMMARY", "")),
            "start": int(local_datetime(start).timestamp() * 1000),
            "end": int(local_datetime(end).timestamp() * 1000),
            "allDay": not isinstance(start, datetime),
            "url": meeting_link(event),
        })
    return events


def main() -> None:
    first_of_month = date.today().replace(day=1)
    window_start = datetime.combine((first_of_month - timedelta(days=1)).replace(day=1), time()).astimezone()
    window_end = datetime.combine(date(first_of_month.year + (first_of_month.month + 2) // 12, (first_of_month.month + 2) % 12 + 1, 1), time()).astimezone()
    try:
        events = [event for url in feed_urls() for event in feed_events(url, window_start, window_end)]
    except Exception as error:
        print(f"agenda: {error}", file=sys.stderr)
        if CACHE_FILE.exists():
            print(CACHE_FILE.read_text())
        return
    output = json.dumps({"configured": bool(feed_urls()), "events": events})
    CACHE_FILE.parent.mkdir(parents=True, exist_ok=True)
    CACHE_FILE.write_text(output)
    print(output)


if __name__ == "__main__":
    main()
