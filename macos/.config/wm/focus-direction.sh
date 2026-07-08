#!/bin/sh
# Focus the window in $1; if there is none, focus the display in that direction.
# Usage: focus-direction.sh north|east|south|west
#
# yabai exits 1 on directional failure, which is what makes the fall-through
# reliable. Never test $? after a pipeline — it reports the pipeline's last
# command, not yabai's.
#
# KNOWN LIMITATION: `display --focus` silently no-ops (exit 0) when the target
# display's active space has no windows — macOS focuses a display by focusing a
# window on it. Throw a window over with move-to-display.sh first. There is no
# workaround at the yabai layer.
set -u

YABAI=/opt/homebrew/bin/yabai

case "${1:-}" in
    north|east|south|west) dir=$1 ;;
    *) printf 'usage: %s north|east|south|west\n' "$(basename "$0")" >&2; exit 2 ;;
esac

"$YABAI" -m window --focus "$dir" 2>/dev/null && exit 0
exec "$YABAI" -m display --focus "$dir"
