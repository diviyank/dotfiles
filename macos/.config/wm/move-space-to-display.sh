#!/bin/sh
# Move the focused space to the display in $1, and follow it.
# Usage: move-space-to-display.sh north|east|south|west
#
# `space --display` makes the moved space visible on the destination but does NOT
# move focus (verified), so `display --focus` follows it. Both exit 1 when there
# is no display that way, so on a single display this is a clean no-op.
#
# Directional selectors resolve relative to the FOCUSED display, which is exactly
# right for a keybinding: the active space on the display you are looking at moves
# in the requested direction. Requires the scripting addition (loaded at startup).
set -u

YABAI=/opt/homebrew/bin/yabai

case "${1:-}" in
    north|east|south|west) dir=$1 ;;
    *) printf 'usage: %s north|east|south|west\n' "$(basename "$0")" >&2; exit 2 ;;
esac

"$YABAI" -m space --display "$dir" 2>/dev/null || exit 0

# The moved space is now visible on the destination, so focusing that display
# follows it. (If the moved space is empty, macOS cannot focus the display and
# this is a no-op -- the space still moved.)
exec "$YABAI" -m display --focus "$dir"
