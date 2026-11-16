#!/bin/sh
set -eu

package_dir="$(cd "$(dirname "$0")" && pwd)"
agent="$HOME/Library/LaunchAgents/local.celestia.launcher.plist"

swift build -c release --package-path "$package_dir"
mkdir -p "$HOME/.local/bin"
cp "$package_dir/.build/release/celestia-launcher" "$HOME/.local/bin/celestia-launcher"

launchctl bootout "gui/$(id -u)/local.celestia.launcher" 2>/dev/null || true
launchctl bootstrap "gui/$(id -u)" "$agent"
