#!/bin/sh
set -u
here="$(cd "$(dirname "$0")" && pwd)"
script="$here/../../.local/bin/celestia-wallpaper"
fails=0

setup() {
    tmp="$(cd "$(mktemp -d)" && pwd -P)"
    stubs="$tmp/stubs"; mkdir -p "$stubs"
    log="$tmp/log"; : > "$log"
    for tool in osascript sips matugen; do
        cat > "$stubs/$tool" <<STUB
#!/bin/sh
echo "$tool" >> "$log"
for a in "\$@"; do printf '  %s\n' "\$a" >> "$log"; done
exit \${STUB_EXIT_$tool:-0}
STUB
        chmod +x "$stubs/$tool"
    done
    export PATH="$stubs:$PATH" HOME="$tmp/home" CELESTIA_STATE_DIR="$tmp/state"
    mkdir -p "$HOME"
}

run() { "$script" "$@" > "$tmp/out" 2> "$tmp/err"; rc=$?; }

check() { # name condition-exit
    if [ "$2" -eq 0 ]; then echo "ok   $1"; else echo "FAIL $1"; fails=$((fails + 1)); fi
}

has() { grep -qxF -- "$1" "$log"; }

test_sets_all_then_colours() {
    setup; touch "$tmp/a.jpg"; run "$tmp/a.jpg"
    has "  tell application \"System Events\" to tell every desktop to set picture to POSIX file \"$tmp/a.jpg\""
    a=$?
    sargs="$(sed -n '/^sips$/,/^matugen$/p' "$log" | sed '1d;$d' | sed 's/^  //' | tr '\n' ' ')"
    b=0; [ "$sargs" = "-s format jpeg -Z 1024 $tmp/a.jpg --out $CELESTIA_STATE_DIR/source.jpg " ] || b=1
    c=0; [ "$(grep -v '^  ' "$log" | tr '\n' ' ')" = "osascript sips matugen " ] || c=1
    e=0; [ "$("$script" --current)" = "$tmp/a.jpg" ] || e=1
    margs="$(sed -n '/^matugen$/,$p' "$log" | sed '1d' | sed 's/^  //' | tr '\n' ' ')"
    [ "$margs" = "image $CELESTIA_STATE_DIR/source.jpg -t scheme-tonal-spot -m dark -c $HOME/.config/celestia/matugen.toml " ]; f=$?
    check sets_all_then_colours $((rc + a + b + c + e + f))
}

test_relative_path_is_absolutised() {
    setup; touch "$tmp/a.jpg"; (cd "$tmp" && "$script" a.jpg >/dev/null 2>&1)
    [ "$(cat "$CELESTIA_STATE_DIR/wallpaper")" = "$tmp/a.jpg" ]
    check relative_path_is_absolutised $?
}

test_path_with_quotes() {
    setup; f="$tmp/it's \"x\" y.jpg"; touch "$f"; run "$f"
    has "  tell application \"System Events\" to tell every desktop to set picture to POSIX file \"$tmp/it's \\\"x\\\" y.jpg\""; a=$?
    has "  $f"; b=$?
    check path_with_quotes $((rc + a + b))
}

test_missing_file() {
    setup; run "$tmp/nope.jpg"
    [ "$rc" -eq 1 ] && [ "$(cat "$tmp/err")" = "celestia-wallpaper: no such file: $tmp/nope.jpg" ] \
        && [ ! -s "$log" ] && [ ! -e "$CELESTIA_STATE_DIR/wallpaper" ]
    check missing_file $?
}

test_reapply() {
    setup; run --reapply
    [ "$rc" -eq 0 ] && [ ! -s "$log" ] && [ ! -s "$tmp/err" ]; a=$?
    mkdir -p "$CELESTIA_STATE_DIR"; printf '%s\n' "$tmp/a.jpg" > "$CELESTIA_STATE_DIR/wallpaper"
    run --reapply
    [ "$rc" -eq 0 ] && [ "$(grep -v '^  ' "$log")" = "osascript" ]; b=$?
    check reapply $((a + b))
}

test_matugen_failure_keeps_wallpaper() {
    setup; touch "$tmp/a.jpg"; STUB_EXIT_matugen=1 run "$tmp/a.jpg"
    [ "$rc" -eq 1 ] && [ "$(cat "$tmp/err")" = "celestia-wallpaper: matugen failed" ] \
        && [ "$(cat "$CELESTIA_STATE_DIR/wallpaper")" = "$tmp/a.jpg" ]
    check matugen_failure_keeps_wallpaper $?
}

test_sips_failure_skips_colours() {
    setup; touch "$tmp/a.heic"; STUB_EXIT_sips=1 run "$tmp/a.heic"
    [ "$rc" -eq 1 ] && [ "$(cat "$tmp/err")" = "celestia-wallpaper: sips failed" ] \
        && [ "$(cat "$CELESTIA_STATE_DIR/wallpaper")" = "$tmp/a.heic" ] && ! grep -q '^matugen$' "$log"
    check sips_failure_skips_colours $?
}

test_osascript_failure_keeps_state() {
    setup; touch "$tmp/a.jpg"; STUB_EXIT_osascript=1 run "$tmp/a.jpg"
    [ "$rc" -eq 1 ] && [ "$(cat "$tmp/err")" = "celestia-wallpaper: osascript failed" ] \
        && [ ! -e "$CELESTIA_STATE_DIR/wallpaper" ] && [ "$(grep -v '^  ' "$log")" = "osascript" ]
    check osascript_failure_keeps_state $?
}

test_current_without_state() {
    setup; run --current
    [ "$rc" -eq 1 ] && [ ! -s "$tmp/out" ] && [ ! -s "$tmp/err" ]
    check current_without_state $?
}

for t in test_sets_all_then_colours test_relative_path_is_absolutised test_path_with_quotes \
         test_missing_file test_reapply test_matugen_failure_keeps_wallpaper test_sips_failure_skips_colours \
         test_osascript_failure_keeps_state test_current_without_state; do "$t"; done
if [ "$fails" -eq 0 ]; then echo "PASS wallpaper"; else echo "$fails failed"; exit 1; fi
