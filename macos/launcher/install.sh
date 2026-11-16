#!/bin/sh
set -eu

package_dir="$(cd "$(dirname "$0")" && pwd)"
agent="$HOME/Library/LaunchAgents/local.celestia.launcher.plist"
dest="$HOME/.local/bin/celestia-launcher"

swift build -c release --package-path "$package_dir"
launchctl bootout "gui/$(id -u)/local.celestia.launcher" 2>/dev/null || true

mkdir -p "$HOME/.local/bin"
cp "$package_dir/.build/release/celestia-launcher" "$dest.new"
mv -f "$dest.new" "$dest"

launchctl bootstrap "gui/$(id -u)" "$agent"
