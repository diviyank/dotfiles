#!/bin/sh
# Headless regression assertions. Run: sh macos/.config/wm/selftest.sh
set -u

WM_DIR="$(cd "$(dirname "$0")" && pwd)"
YABAI=/opt/homebrew/bin/yabai
SKETCHYBAR=/opt/homebrew/bin/sketchybar
JQ=/usr/bin/jq

fails=0
ok()   { printf 'PASS  %s\n' "$1"; }
bad()  { printf 'FAIL  %s\n' "$1"; fails=$((fails + 1)); }

# --- binaries exist ---
for b in "$YABAI" "$SKETCHYBAR" "$JQ"; do
    if [ -x "$b" ]; then ok "binary $b"; else bad "binary $b missing"; fi
done

# --- profile.sh is pure and correct ---
. "$WM_DIR/profile.sh"

count=$(wm_display_count)
case "$count" in
    ''|*[!0-9]*) bad "wm_display_count returned non-integer '$count'" ;;
    *) [ "$count" -ge 1 ] && ok "wm_display_count = $count" || bad "wm_display_count < 1" ;;
esac

uuids=$(wm_display_uuids | wc -l | tr -d ' ')
[ "$uuids" = "$count" ] && ok "wm_display_uuids yields $uuids line(s)" \
                        || bad "wm_display_uuids yielded $uuids, expected $count"

spaces=$(wm_spaces_on_display 1 | wc -l | tr -d ' ')
[ "$spaces" -ge 1 ] && ok "wm_spaces_on_display 1 yields $spaces space(s)" \
                    || bad "wm_spaces_on_display 1 yielded none"

gap=$(wm_gap_for_display 7B05FE65-87BC-4FFB-9F96-50316B179354)
[ "$gap" = "8" ] && ok "wm_gap_for_display ASUS = 8" || bad "ASUS gap = '$gap', expected 8"

gap=$(wm_gap_for_display __unknown_display__)
[ "$gap" = "3" ] && ok "wm_gap_for_display default = 3" || bad "default gap = '$gap', expected 3"

# --- no wm script may invoke a bare binary ---
# yabai spawns signal actions with a minimal environment. A bare `yabai` or `jq`
# that fails to resolve is the leading theory for how setup_spaces created 11
# orphan spaces from an empty query result.
#
# The `-` in the character class matters: `printf 'apply-yabai FAILED'` would
# otherwise match, since `yabai ` there is preceded by a hyphen.
BARE='(^|[^-/[:alnum:]_.])(yabai|jq|sketchybar)[[:space:]]'
for f in "$WM_DIR"/*.sh; do
    if grep -vE '^[[:space:]]*#' "$f" | grep -qE "$BARE"; then
        bad "$(basename "$f") invokes bare executable (should use absolute /opt/homebrew/bin paths)"
    else
        ok "$(basename "$f") uses absolute binary paths"
    fi
done

stub=$(mktemp -d)
printf '#!/bin/sh\nexit 1\n' > "$stub/yabai"
chmod +x "$stub/yabai"
(
    WM_YABAI="$stub/yabai"
    wm_display_count       >/dev/null 2>&1 && exit 10
    wm_display_uuids       >/dev/null 2>&1 && exit 11
    wm_spaces_on_display 1 >/dev/null 2>&1 && exit 12
    exit 0
)
case $? in
    0)  ok "profile.sh query functions fail when backend fails" ;;
    10) bad "wm_display_count returned 0 with a failing yabai" ;;
    11) bad "wm_display_uuids returned 0 with a failing yabai" ;;
    12) bad "wm_spaces_on_display returned 0 with a failing yabai" ;;
esac
rm -rf "$stub"

# --- apply-yabai.sh is idempotent and loses no rules ---
# yabai discards invalid rules SILENTLY. `.yabairc` declared 5 and only 4 were
# ever live, because `space=0` is invalid (spaces are 1-indexed). Nothing but
# this assertion will ever tell you.
declared=$(grep -c -- '--add label=' "$WM_DIR/apply-yabai.sh")
sh "$WM_DIR/apply-yabai.sh" >/dev/null 2>&1
sh "$WM_DIR/apply-yabai.sh" >/dev/null 2>&1   # twice: proves idempotency
live=$("$YABAI" -m rule --list | "$JQ" 'length')
[ "$declared" = "$live" ] && ok "rules: declared $declared == live $live" \
                          || bad "rules: declared $declared but live $live"

[ "$("$YABAI" -m config external_bar)" = "all:32:0" ] \
    && ok "external_bar = all:32:0" \
    || bad "external_bar = $("$YABAI" -m config external_bar), expected all:32:0"

# --- apply-yabai.sh must capture wm_* exit status, not iterate a substitution ---
# `for x in $(wm_display_uuids)` discards the function's `return 1`: the loop
# just runs zero times and exits 0. Verified. profile.sh's failure signalling is
# worthless unless the caller captures it first.
grep -qE 'for [A-Za-z_]+ in \$\(wm_' "$WM_DIR/apply-yabai.sh" \
    && bad "apply-yabai.sh iterates \$(wm_...) directly, discarding its exit status" \
    || ok "apply-yabai.sh captures wm_* exit status before iterating"

printf '\n%s failure(s)\n' "$fails"
[ "$fails" -eq 0 ]
