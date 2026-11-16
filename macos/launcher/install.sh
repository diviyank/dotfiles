#!/bin/sh
set -eu

package_dir="$(cd "$(dirname "$0")" && pwd)"
agent="$HOME/Library/LaunchAgents/local.celestia.launcher.plist"
dest="$HOME/.local/bin/celestia-launcher"
domain="gui/$(id -u)"
service="$domain/local.celestia.launcher"

swift build -c release --package-path "$package_dir"

mkdir -p "$HOME/.local/bin"
cp "$package_dir/.build/release/celestia-launcher" "$dest.new"
mv -f "$dest.new" "$dest"

if launchctl print "$service" >/dev/null 2>&1; then
    launchctl kickstart -k "$service"
else
    launchctl bootstrap "$domain" "$agent"
fi
