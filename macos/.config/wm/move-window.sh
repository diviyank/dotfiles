#!/bin/sh
# Move the focused window in $1 within its space; at the space's edge, move it to
# the adjacent display and follow it.
# Usage: move-window.sh north|east|south|west
#
# yabai exits 1 when there is no window that way, which is what makes the
# fall-through reliable. Never test $? after a pipeline.
set -u

YABAI=/opt/homebrew/bin/yabai
JQ=/usr/bin/jq

case "${1:-}" in
    north|east|south|west) dir=$1 ;;
    *) printf 'usage: %s north|east|south|west\n' "$(basename "$0")" >&2; exit 2 ;;
esac

# Move within the bsp tree first. Exits 0 when there was a window that way.
"$YABAI" -m window --warp "$dir" 2>/dev/null && exit 0

# At the edge of the space: move the window to the adjacent display and follow.
# `yabai | jq` exits 0 even when yabai fails, so validate the id value.
id=$("$YABAI" -m query --windows --window | "$JQ" -r '.id')
case "$id" in
    ''|null|*[!0-9]*) exit 1 ;;   # no focused window
esac

# No display that way: clean no-op, matching single-display behaviour.
"$YABAI" -m window --display "$dir" 2>/dev/null || exit 0

"$YABAI" -m display --focus "$dir" 2>/dev/null
exec "$YABAI" -m window --focus "$id"
