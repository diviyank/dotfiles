#!/bin/sh
# Focus the window in $1; at the edge of the space, focus the display in that
# direction -- landing on that display's currently-visible space, deterministically.
# Usage: focus-direction.sh north|east|south|west
#
# yabai exits 1 on directional failure. Never test $? after a pipeline.
#
# A plain `display --focus <dir>` restores yabai's remembered window for that
# display, which under focus_follows_mouse=autofocus + mouse_follows_focus can
# land on a sticky/floating window and switch to the wrong space. Instead we pick
# the first managed window on the target display's visible space and focus it, so
# the mouse warps there and autofocus keeps it -- returning to the space you left.
#
# KNOWN LIMITATION: if the target display's visible space has no managed window,
# there is nothing to focus and this falls back to `display --focus`, which
# macOS treats as a no-op on an empty display. Throw a window over first.
set -u

YABAI=/opt/homebrew/bin/yabai
JQ=/usr/bin/jq

case "${1:-}" in
    north|east|south|west) dir=$1 ;;
    *) printf 'usage: %s north|east|south|west\n' "$(basename "$0")" >&2; exit 2 ;;
esac

# Within the current space first.
"$YABAI" -m window --focus "$dir" 2>/dev/null && exit 0

# Edge of the space: find the display in that direction (relative to focus).
tgt=$("$YABAI" -m query --displays --display "$dir" 2>/dev/null | "$JQ" -r '.index // empty')
case "$tgt" in
    ''|*[!0-9]*) exit 1 ;;   # no display that way
esac

# Focus that display's visible-space first managed window (deterministic).
wid=$("$YABAI" -m query --windows --display "$tgt" | "$JQ" -r '
    [ .[] | select(.["is-visible"] and (.["is-minimized"] | not)
                   and (.["is-sticky"] | not) and (.["is-floating"] | not)) ]
    | sort_by(.frame.x, .frame.y) | .[0].id // empty')

[ -n "$wid" ] && exec "$YABAI" -m window --focus "$wid"

# Visible space has no managed window: best effort (no-op on an empty display).
exec "$YABAI" -m display --focus "$dir"
