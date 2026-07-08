#!/bin/sh
# Sole owner of external_bar, per-space gaps, and app rules.
# Idempotent: it runs on every display change.
set -u

WM_DIR="$(cd "$(dirname "$0")" && pwd)"
. "$WM_DIR/profile.sh"

YABAI=/opt/homebrew/bin/yabai

# Abort rather than assume a topology. Never fall back to "one display".
#
# CAPTURE, then iterate. Passing a command substitution directly to a for-loop
# would DISCARD the function's exit status — the substitution runs in a subshell,
# so a failed query becomes a zero-iteration loop that reports success. Verified.
uuids=$(wm_display_uuids) || {
    printf 'wm: display query failed; refusing to apply\n' >&2
    exit 1
}

# Bar is height=32. This was all:40:0.
"$YABAI" -m config external_bar all:32:0

# wm_display_uuids yields one uuid per line in index order, so the counter is
# the display index. UUIDs contain no whitespace, so word-splitting is safe.
i=1
for uuid in $uuids; do
    gap=$(wm_gap_for_display "$uuid")

    spaces=$(wm_spaces_on_display "$i") || {
        printf 'wm: space query failed for display %s; refusing to apply\n' "$i" >&2
        exit 1
    }

    for s in $spaces; do
        for k in window_gap top_padding bottom_padding left_padding right_padding; do
            "$YABAI" -m config --space "$s" "$k" "$gap"
        done
    done
    i=$((i + 1))
done

# `label=` makes re-adding idempotent (verified: re-adding replaces, it does not
# duplicate). Without labels this would accumulate a rule per hotplug.
# `work` was space=0 in .yabairc, which yabai silently discarded.
"$YABAI" -m rule --add label=music app="^(Spotify|Amazon Music)$"           space=9
"$YABAI" -m rule --add label=ical  app="^(iCal)$"                           space=8
"$YABAI" -m rule --add label=mail  app="^(Mail)$"                           space=7
"$YABAI" -m rule --add label=chat  app="^(Discord)$"                        space=6
"$YABAI" -m rule --add label=work  app="^(Slack|WhatsApp|Microsoft Teams)$" space=10
