#!/bin/sh
# Pure. Source this; never execute it. No side effects.
#
# NOTE: `yabai ... | jq length` exits 0 even when yabai fails, because the
# pipeline reports jq's status. Every consumer must therefore validate the
# value, not the exit code. Creating spaces from an unvalidated count is what
# produced 11 orphan spaces.

WM_YABAI=/opt/homebrew/bin/yabai
WM_JQ=/usr/bin/jq

wm_display_count() {
    _count=$("$WM_YABAI" -m query --displays | "$WM_JQ" 'length')
    case "$_count" in
        ''|*[!0-9]*) return 1 ;;
    esac
    [ "$_count" -ge 1 ] || return 1
    printf '%s\n' "$_count"
}

wm_display_uuids() {
    "$WM_YABAI" -m query --displays | "$WM_JQ" -r 'sort_by(.index)[].uuid'
}

wm_spaces_on_display() {
    "$WM_YABAI" -m query --spaces --display "$1" | "$WM_JQ" -r '.[].index'
}

# Gaps key on UUID, not on width: the built-in is 1710px wide and the ASUS
# 1920px, so no width threshold can separate them.
wm_gap_for_display() {
    case "$1" in
        7B05FE65-87BC-4FFB-9F96-50316B179354) printf '8\n' ;;  # ASUS PA248QV
        37D8832A-2D66-02CA-B9F7-8F30A301B230) printf '3\n' ;;  # built-in Color LCD
        *)                                    printf '3\n' ;;
    esac
}
