#!/bin/sh
set -u
here="$(cd "$(dirname "$0")" && pwd)"
script="$here/../../.local/bin/celestia"
fails=0

setup() {
    tmp="$(mktemp -d)"
    stubs="$tmp/stubs"; mkdir -p "$stubs"
    log="$tmp/log"; : > "$log"
    for tool in launchctl yabai skhd; do
        # shellcheck disable=SC2016
        printf '#!/bin/sh\necho "%s $*" >> "%s"\nexit ${STUB_EXIT:-0}\n' "$tool" "$log" > "$stubs/$tool"
        chmod +x "$stubs/$tool"
    done
    export PATH="$stubs:$PATH" HOME="$tmp/home"
}

check() { if [ "$2" -eq 0 ]; then echo "ok   $1"; else echo "FAIL $1"; fails=$((fails + 1)); fi; }

test_restart_all() {
    setup; "$script" restart >/dev/null 2>&1
    uid="$(id -u)"
    [ "$(cat "$log")" = "launchctl kickstart -k gui/$uid/local.celestia.shell
yabai --restart-service
skhd --restart-service" ]
    check restart_all $?
}

test_stop_one() {
    setup; "$script" stop yabai >/dev/null 2>&1
    [ "$(cat "$log")" = "yabai --stop-service" ]
    check stop_one $?
}

test_start_shell() {
    setup; "$script" start shell >/dev/null 2>&1
    [ "$(cat "$log")" = "launchctl bootstrap gui/$(id -u) $HOME/Library/LaunchAgents/local.celestia.shell.plist" ]
    check start_shell $?
}

test_stop_shell() {
    setup; "$script" stop shell >/dev/null 2>&1
    [ "$(cat "$log")" = "launchctl bootout gui/$(id -u)/local.celestia.shell" ]
    check stop_shell $?
}

test_bad_usage() {
    setup; "$script" explode >/dev/null 2>&1; a=$?
    "$script" start nope >/dev/null 2>&1; b=$?
    [ "$a" -eq 2 ] && [ "$b" -eq 2 ] && [ ! -s "$log" ]
    check bad_usage $?
}

test_failure_is_reported() {
    setup; STUB_EXIT=1 "$script" restart skhd >/dev/null 2>&1
    [ $? -eq 1 ]
    check failure_is_reported $?
}

for t in test_restart_all test_stop_one test_start_shell test_stop_shell test_bad_usage test_failure_is_reported; do "$t"; done
if [ "$fails" -eq 0 ]; then echo "PASS celestia"; else echo "$fails failed"; exit 1; fi
