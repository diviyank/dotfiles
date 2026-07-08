#!/bin/sh
# Move the focused window to the display in $1 and follow it.
# Usage: move-to-display.sh north|east|south|west
#
# The id capture matters: `display --focus` focuses that display's focused
# window, not necessarily the one just thrown.
#
# `yabai | jq` exits 0 even when yabai fails, so validate the id, not the
# exit code.
set -u

YABAI=/opt/homebrew/bin/yabai
JQ=/usr/bin/jq

case "${1:-}" in
    north|east|south|west) dir=$1 ;;
    *) printf 'usage: %s north|east|south|west\n' "$(basename "$0")" >&2; exit 2 ;;
esac

id=$("$YABAI" -m query --windows --window | "$JQ" -r '.id')
case "$id" in
    ''|null|*[!0-9]*) exit 1 ;;   # no focused window
esac

# No display that way: clean no-op, matching single-display behaviour.
"$YABAI" -m window --display "$dir" 2>/dev/null || exit 0

"$YABAI" -m display --focus "$dir" 2>/dev/null
exec "$YABAI" -m window --focus "$id"
