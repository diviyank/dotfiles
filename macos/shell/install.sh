#!/bin/sh
set -eu

package_dir="$(cd "$(dirname "$0")" && pwd)"
agent="$HOME/Library/LaunchAgents/local.celestia.shell.plist"
dest="$HOME/.local/bin/celestia-shell"
domain="gui/$(id -u)"

swift build -c release --package-path "$package_dir"

mkdir -p "$HOME/.local/bin"
cp "$package_dir/.build/release/celestia-shell" "$dest.new"
mv -f "$dest.new" "$dest"

launchctl bootout "$domain/local.celestia.launcher" 2>/dev/null || true
rm -f "$HOME/.local/bin/celestia-launcher"

launchctl bootout "$domain/local.celestia.shell" 2>/dev/null || true
tries=0
while launchctl print "$domain/local.celestia.shell" >/dev/null 2>&1 && [ "$tries" -lt 50 ]; do
    sleep 0.1
    tries=$((tries + 1))
done
launchctl bootstrap "$domain" "$agent"
