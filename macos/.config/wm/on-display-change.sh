#!/bin/sh
# Fired by yabai display signals. Debounced: one physical plug-in emits
# display_added + display_moved + display_resized within a second or two, and
# macOS is still reassigning spaces after the last one lands.
#
# Absolute paths are mandatory: yabai spawns signal actions with a minimal
# environment.
set -u

WM_DIR="$(cd "$(dirname "$0")" && pwd)"
LOCK="${WM_LOCK:-${TMPDIR:-/tmp}/wm-display-change.lock}"
LOG="${WM_LOG:-$HOME/.cache/wm/display-change.log}"
DEBOUNCE="${WM_DEBOUNCE:-1.5}"
APPLY="${WM_APPLY:-$WM_DIR/apply-yabai.sh}"
SKETCHYBAR="${WM_SKETCHYBAR:-/opt/homebrew/bin/sketchybar}"

mkdir -p "$(dirname "$LOG")"

# Last writer wins.
printf '%s\n' "$$" > "$LOCK"
sleep "$DEBOUNCE"
[ "$(cat "$LOCK" 2>/dev/null)" = "$$" ] || exit 0

printf 'apply %s pid=%s\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')" "$$" >> "$LOG"

if ! "$APPLY" >> "$LOG" 2>&1; then
    printf 'apply-yabai FAILED\n' >> "$LOG"
fi

"$SKETCHYBAR" --reload >> "$LOG" 2>&1
