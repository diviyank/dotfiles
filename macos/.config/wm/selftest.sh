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

gap=$(wm_gap_for_display EFF5329B-AEAE-4210-80F0-953761D1FC53)
[ "$gap" = "8" ] && ok "wm_gap_for_display Dell = 8" || bad "Dell gap = '$gap', expected 8"

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
#
# Remove the declared labels first. yabai keeps a previously-good rule when a
# re-add is rejected, so a warm rule list masks a silently-discarded rule --
# which is precisely the bug this guard exists to catch. yabai startup runs
# apply-yabai.sh against an empty rule list; test that path.
for lbl in $(grep -oE -- '--add label=[A-Za-z0-9_-]+' "$WM_DIR/apply-yabai.sh" | cut -d= -f2); do
    "$YABAI" -m rule --remove "$lbl" >/dev/null 2>&1
done

sh "$WM_DIR/apply-yabai.sh" >/dev/null 2>&1
sh "$WM_DIR/apply-yabai.sh" >/dev/null 2>&1   # twice: proves idempotency

rule_fail=0
for lbl in $(grep -oE -- '--add label=[A-Za-z0-9_-]+' "$WM_DIR/apply-yabai.sh" | cut -d= -f2); do
    n=$("$YABAI" -m rule --list | "$JQ" --arg l "$lbl" '[.[] | select(.label == $l)] | length')
    if [ "$n" != "1" ]; then
        bad "rule '$lbl' appears $n time(s) in the live list, expected exactly 1"
        rule_fail=1
    fi
done
[ "$rule_fail" -eq 0 ] && ok "every declared rule label is live exactly once"

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

# --- the per-display gap loop is apply-yabai.sh's whole purpose; assert it ran ---
# Without this, apply-yabai.sh could apply no gaps at all and every other
# assertion would still pass.
sh "$WM_DIR/apply-yabai.sh" >/dev/null 2>&1
gap_fail=0
gap_uuids=$(wm_display_uuids) || { bad "wm_display_uuids failed"; gap_fail=1; }
i=1
for u in $gap_uuids; do
    want=$(wm_gap_for_display "$u")
    gap_spaces=$(wm_spaces_on_display "$i") || { bad "no spaces on display $i"; gap_fail=1; break; }
    for s in $gap_spaces; do
        got=$("$YABAI" -m config --space "$s" window_gap)
        if [ "$got" != "$want" ]; then
            bad "display $i space $s window_gap=$got, expected $want"
            gap_fail=1
            break
        fi
    done
    i=$((i + 1))
done
[ "$gap_fail" -eq 0 ] && ok "per-space window_gap matches wm_gap_for_display on every display"

# --- debounce: one physical hotplug fires 3-4 signals; only the last must apply ---
# WM_APPLY / WM_SKETCHYBAR are stubbed: this asserts the debounce, not the effects.
tmp=$(mktemp -d)
i=1
while [ "$i" -le 4 ]; do
    WM_LOCK="$tmp/lock" WM_LOG="$tmp/log" WM_DEBOUNCE=0.4 \
    WM_APPLY=/usr/bin/true WM_SKETCHYBAR=/usr/bin/true \
        sh "$WM_DIR/on-display-change.sh" &
    i=$((i + 1))
done
wait
applied=$(grep -c '^apply ' "$tmp/log" 2>/dev/null || printf '0')
[ "$applied" = "1" ] && ok "debounce: 4 concurrent invocations -> 1 apply" \
                     || bad "debounce: got $applied applies, expected 1"
rm -rf "$tmp"

# --- .skhdrc must not read $? after a pipeline (bug 5) ---
SKHDRC="${SKHDRC:-$HOME/dotfiles/.skhdrc}"
grep -q '\$?' "$SKHDRC" && bad ".skhdrc still tests \$? (unreliable after a pipeline)" \
                        || ok ".skhdrc has no \$? test"

# --- the reload binding must target a service that exists (bug 9) ---
grep -q 'homebrew.mxcl.yabai' "$SKHDRC" \
    && bad ".skhdrc kickstarts homebrew.mxcl.yabai, which does not exist" \
    || ok ".skhdrc does not reference homebrew.mxcl.yabai"

# --- direction scripts reject bad input rather than doing something arbitrary ---
before=$("$YABAI" -m query --displays --display | "$JQ" -r '.index')

sh "$WM_DIR/focus-direction.sh" >/dev/null 2>&1 \
    && bad "focus-direction.sh with no argument exited 0" \
    || ok "focus-direction.sh rejects a missing argument"

sh "$WM_DIR/focus-direction.sh" __bogus__ >/dev/null 2>&1 \
    && bad "focus-direction.sh __bogus__ exited 0" \
    || ok "focus-direction.sh rejects an invalid direction"

sh "$WM_DIR/move-to-display.sh" >/dev/null 2>&1 \
    && bad "move-to-display.sh with no argument exited 0" \
    || ok "move-to-display.sh rejects a missing argument"

after=$("$YABAI" -m query --displays --display | "$JQ" -r '.index')
[ "$before" = "$after" ] && ok "bad input did not move focus (display $before)" \
                         || bad "focus moved from display $before to $after on bad input"

# --- the bar must come back after a reload (on-display-change.sh depends on it) ---
"$SKETCHYBAR" --reload >/dev/null 2>&1
sleep 1
items=$("$SKETCHYBAR" --query bar | "$JQ" '.items | length')
case "$items" in
    ''|*[!0-9]*) bad "bar item count unreadable: '$items'" ;;
    *) [ "$items" -gt 0 ] && ok "bar has $items items after reload" \
                          || bad "bar has no items after reload" ;;
esac

# --- every .yabairc signal must be labelled and registered exactly once ---
# `signal --add` WITHOUT a label appends, so re-sourcing .yabairc duplicates every
# signal. With a label it replaces. Same class of bug as the unlabelled app rules.
YABAIRC="${YABAIRC:-$HOME/dotfiles/.yabairc}"

declared_sigs=$(grep -vE '^[[:space:]]*#' "$YABAIRC" | grep -c -- 'signal --add')
labelled_sigs=$(grep -vE '^[[:space:]]*#' "$YABAIRC" | grep -c -- 'signal --add label=')
[ "$declared_sigs" = "$labelled_sigs" ] \
    && ok "all $declared_sigs signals in .yabairc carry a label" \
    || bad "$((declared_sigs - labelled_sigs)) signal(s) in .yabairc lack a label (re-sourcing would duplicate them)"

sig_fail=0
for lbl in $(grep -vE '^[[:space:]]*#' "$YABAIRC" | grep -oE -- '--add label=[A-Za-z0-9_-]+' | cut -d= -f2); do
    n=$("$YABAI" -m signal --list | "$JQ" --arg l "$lbl" '[.[] | select(.label == $l)] | length')
    if [ "$n" != "1" ]; then
        bad "signal '$lbl' appears $n time(s) in the live list, expected exactly 1"
        sig_fail=1
    fi
done
[ "$sig_fail" -eq 0 ] && ok "every declared signal label is registered exactly once"

printf '\n%s failure(s)\n' "$fails"
[ "$fails" -eq 0 ]
