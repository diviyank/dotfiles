#!/bin/sh
# Sole owner of space labels, external_bar, per-space gaps, and app rules.
# Idempotent: it runs on every display change.
set -u

WM_DIR="$(cd "$(dirname "$0")" && pwd)"
. "$WM_DIR/profile.sh"

YABAI=/opt/homebrew/bin/yabai

# Before anything else: a hotplug can destroy the space holding a label, and
# skhd selects spaces by label. Re-run on every change so a lost name is healed.
if ! "$WM_DIR/relabel-spaces.sh"; then
    printf 'wm: relabel-spaces.sh FAILED -- some space labels may be missing\n' >&2
fi

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
#
# Target spaces by LABEL, never index: indices renumber on hotplug and on
# cross-display space moves (space=10 was landing Teams on "eleven", the
# scratchpad space). yabai resolves the label to an index when the rule is
# added, so this must re-run whenever indices shift -- hence the call from
# move-space-to-display.sh as well as the display signals.
"$YABAI" -m rule --add label=music app="^(Spotify|Amazon Music)$"           space=nine
"$YABAI" -m rule --add label=ical  app="^(iCal)$"                           space=eight
"$YABAI" -m rule --add label=mail  app="^(Mail)$"                           space=seven
"$YABAI" -m rule --add label=chat  app="^(Discord)$"                        space=six
"$YABAI" -m rule --add label=work  app="^(Slack|WhatsApp|Microsoft Teams)$" space=ten

# Rules only fire on window creation; --apply re-homes windows already open.
"$YABAI" -m rule --apply
