#!/bin/sh
# Guarantees every name in SPACE_NAMES is carried by exactly one space.
#
# Labels are the stable space identity: skhd focuses by label, and the
# scratchpad hides by label. Indices are positional and renumber whenever a
# display is attached, so labelling by index (what .yabairc used to do at login)
# silently breaks after a hotplug -- macOS destroys and recreates spaces, the
# names on them are lost, and `--focus two` starts erroring out.
#
# Existing labels are never reassigned. Only nameless spaces are filled, so a
# space keeps its identity across every topology change.
set -u

YABAI=/opt/homebrew/bin/yabai
JQ=/usr/bin/jq

SPACE_NAMES='one two three four five six seven eight nine ten eleven'

spaces=$("$YABAI" -m query --spaces) || {
    printf 'wm: space query failed; labels left as-is\n' >&2
    exit 1
}

taken=$(printf '%s' "$spaces" | "$JQ" -r '.[].label | select(. != "")')
unlabeled=$(printf '%s' "$spaces" | "$JQ" -r '.[] | select(.label == "") | .index')

for name in $SPACE_NAMES; do
    for held in $taken; do
        [ "$name" = "$held" ] && continue 2
    done

    # First nameless space wins; consume it so the next name gets a different one.
    index=$(printf '%s\n' $unlabeled | head -n 1)
    if [ -z "$index" ]; then
        printf 'wm: no nameless space left for label %s\n' "$name" >&2
        continue
    fi
    unlabeled=$(printf '%s\n' $unlabeled | tail -n +2)

    "$YABAI" -m space "$index" --label "$name"
done
