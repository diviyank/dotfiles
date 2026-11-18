#!/bin/sh
set -eu
here="$(cd "$(dirname "$0")" && pwd)"
wall="${CELESTIA_TEST_WALLPAPER:-$HOME/.local/state/celestia/source.jpg}"
tmp="$(mktemp -d)"
trap "rm -rf \"\$tmp\"" EXIT
out="$tmp/.local/state/celestia"
mkdir -p "$tmp/.config"
cp -R "$here/../../.config/celestia" "$tmp/.config/celestia"

HOME="$tmp" CELESTIA_NO_RELOAD=1 matugen image "$wall" -t scheme-tonal-spot -m dark -c "$tmp/.config/celestia/matugen.toml" >/dev/null

jq -e '[.primary,.on_surface,.surface_container] | all(test("^#[0-9a-f]{6}$"))' "$out/colors.json" >/dev/null
jq -e 'keys|length==25' "$out/colors.json" >/dev/null
[ "$(grep -cE '^color([0-9]|1[0-5]) #[0-9a-f]{6}$' "$out/kitty.conf")" -eq 16 ]
! grep -qE '^(background|foreground) ' "$out/kitty.conf"
! grep -q '{{' "$out/kitty.conf" "$out/tmux.conf"
grep -qE "^set -g status-style 'fg=#[0-9a-f]{6}'$" "$out/tmux.conf"
echo "PASS templates"
