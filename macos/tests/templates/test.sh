#!/bin/sh
set -eu
here="$(cd "$(dirname "$0")" && pwd)"
wall="${CELESTIA_TEST_WALLPAPER:-$HOME/Pictures/Wallpapers/lakes-02-lake-hawea-05.jpg}"
tmp="$(mktemp -d)"
trap "rm -rf \"\$tmp\"" EXIT
out="$tmp/.local/state/celestia"
mkdir -p "$tmp/.config"
cp -R "$here/../../.config/celestia" "$tmp/.config/celestia"

HOME="$tmp" matugen image "$wall" -t scheme-tonal-spot -m dark -c "$tmp/.config/celestia/matugen.toml" >/dev/null

lua -e "local c=dofile('$out/colors.lua') for _,k in ipairs{'primary','on_primary','primary_container','on_primary_container','secondary','on_secondary','secondary_container','on_secondary_container','tertiary','on_tertiary','tertiary_container','on_tertiary_container','error','on_error','surface','on_surface','on_surface_variant','surface_container_low','surface_container','surface_container_high','surface_container_highest','outline','outline_variant','shadow','scrim'} do assert(math.type(c[k])=='integer' and c[k]>=0xff000000, k) end"
jq -e '[.primary,.on_surface,.surface_container] | all(test("^#[0-9a-f]{6}$"))' "$out/colors.json" >/dev/null
jq -e 'keys|length==25' "$out/colors.json" >/dev/null
echo "PASS templates"
