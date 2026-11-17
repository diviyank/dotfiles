#!/bin/sh
set -eu
here="$(cd "$(dirname "$0")" && pwd)"
wall="${CELESTIA_TEST_WALLPAPER:-$HOME/.local/state/celestia/source.jpg}"
tmp="$(mktemp -d)"
trap "rm -rf \"\$tmp\"" EXIT
out="$tmp/.local/state/celestia"
mkdir -p "$tmp/.config"
cp -R "$here/../../.config/celestia" "$tmp/.config/celestia"

HOME="$tmp" matugen image "$wall" -t scheme-tonal-spot -m dark -c "$tmp/.config/celestia/matugen.toml" >/dev/null

jq -e '[.primary,.on_surface,.surface_container] | all(test("^#[0-9a-f]{6}$"))' "$out/colors.json" >/dev/null
jq -e 'keys|length==25' "$out/colors.json" >/dev/null
echo "PASS templates"
