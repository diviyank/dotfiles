# CelestiaMacOS Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give the yabai work Mac the Caelestia look (SbarLua bar + clock dashboard popup, Material You colours from the wallpaper) and a native Caelestia-style launcher with `>wallpaper`.

**Architecture:** One colour pipeline (`celestia-wallpaper` → matugen → `~/.local/state/celestia/colors.{lua,json}`, with committed defaults) feeds two consumers: a SketchyBar config rewritten in Lua (SbarLua) and a resident Swift/AppKit launcher toggled from skhd via a distributed notification. Everything is built and tested from Linux (Lua stub harness, shell stubs, Swift `LauncherCore` tests in Docker); each task ends with an on-Mac check the user runs.

**Tech Stack:** SketchyBar + SbarLua (Lua 5.4), zsh/sh, matugen 2.4.1, osascript, Swift 6 / SwiftPM / AppKit, skhd, launchd, GNU stow.

**Spec:** `/home/diviyan/Documents/specs/2026-11-16-celestia-macos-design.md`

**Worktree:** `/home/diviyan/dotfiles-celestia-macos`, branch `rice/celestia-macos` (from `origin/macos`). All paths below are relative to it.

## Global Constraints

- Commits: `[DEV] <title>`, no body, no trailers (no Co-Authored-By, no "Claude"). Never commit specs/plans.
- Minimal diff: don't touch wm scripts, `.yabairc`, AeroSpace files or existing skhd binds except where a task says so.
- All new Mac files under `macos/` (stowed with `stow -t ~ macos`). Non-dotfiles in `macos/` (`README.md`, `SHORTCUTS.md`, `launcher/`, `tests/`) must be listed in `macos/.stow-local-ignore` (Task 7) — until then, don't worry about them being linked.
- Absolute tool paths in anything yabai/skhd/launchd spawns: `/opt/homebrew/bin/{yabai,sketchybar,lua}`, `/usr/bin/jq`, `/usr/bin/osascript`. Scripts *append* `/opt/homebrew/bin:$HOME/.cargo/bin:$HOME/.local/bin` to PATH (append, so test stubs placed first in PATH win).
- matugen: `matugen image <file> -t scheme-tonal-spot -m dark -c ~/.config/celestia/matugen.toml`. Pinned to 2.4.1 (Linux has `~/.local/bin/matugen` 2.4.1; Mac installs `cargo install matugen --locked --version 2.4.1`).
- Generated colours: `~/.local/state/celestia/colors.lua` and `colors.json`. Defaults (committed): `macos/.config/celestia/default-colors.lua` and `default-colors.json`. Colour role keys (both files, exactly these, matugen snake_case names): `primary on_primary primary_container on_primary_container secondary on_secondary secondary_container on_secondary_container tertiary on_tertiary tertiary_container on_tertiary_container error on_error surface on_surface on_surface_variant surface_container_low surface_container surface_container_high surface_container_highest outline outline_variant shadow scrim`. Lua values are `0xffRRGGBB` integers; JSON values are `"#rrggbb"` strings.
- **Caelestia look — exact values (Linux renders Qt pt at 96 dpi, so Mac points = Caelestia px = round(pt × 4/3)):**
  - Fonts: text `Google Sans Flex` (Caelestia's `GoogleSansFlex`), numbers of spaces `Rubik`, icons `Material Symbols Rounded`, mono `CaskaydiaCove Nerd Font Mono`. Every family name lives in one place per consumer (`theme.lua`, `Theme.swift`).
  - Text sizes (Mac pt): label.small 15, label.medium 16 Medium, body.small 16, body.medium 19, body.large 21, title.small 19 Medium, mono.small 16. Clock = body.small × 1.1 → 18.
  - Icon sizes (Mac pt): small 20, medium 24, large 32, extraLarge 48.
  - Rounding (user scale 0.75): small 6, medium 9, large 12, extraLarge 21, full = height/2. Padding/spacing (scale 1): extraSmall 4, small 8, medium 12, large 16.
  - Durations: small 200 ms, normal 400 ms, expressive spatial 500 ms. SketchyBar animates in 60 fps frames: 200 ms = 12, 400 ms = 24, 500 ms = 30; curve `tanh`.
  - Icon glyphs are Material Symbols **codepoints** (not ligature names), built with `utf8.char` / Swift `Character(Unicode.Scalar(...))`: calendar_month U+EBCC, clear_day U+F157, partly_cloudy_day U+F172, partly_cloudy_night U+F174, bedtime U+F159, cloud U+F15C, foggy U+E818, rainy U+F176, cloudy_snowing U+E810, snowing_heavy U+F61C, thunderstorm U+EBDB, music_note U+E405, play_arrow U+E037, pause U+E034, skip_next U+E044, skip_previous U+E045, battery_full U+E1A5, battery_charging_full U+E1A3, battery_0_bar…battery_6_bar U+EBDC U+F09C U+F09D U+F09E U+F09F U+F0A0 U+F0A1, volume_up U+E050, volume_down U+E04D, volume_mute U+E04E, volume_off U+E04F, mail U+E159, forum U+E8AF, notifications U+E7F5, timer U+E425, coffee U+EFEF, desktop_windows U+E30C, terminal U+EB8E, web U+E051, code U+E86F, chat U+E0C9, folder U+E2C7, settings U+E8B8, search U+E8B6, wallpaper U+E1BC, image U+E3F4, chevron_right U+E5CC.
  - Colour roles (from Caelestia's QML): bar pills `surface_container`; current space pill `primary` with `on_primary` number (Rubik); front-app icon + title `primary`; clock icon + text `tertiary`; status icons (battery, volume, mail, Discord, pomodoro) `secondary`; battery ≤ 20 % and not charging `error`; attention `error`; secondary text `outline`; dimmed text `outline_variant`; popup/launcher surface `surface`; highlight = `on_surface` at 8 % alpha; search field `surface_container`, search icon `on_surface_variant`.
  - Battery icon rule (Caelestia `getBatteryIcon`): 100 % → battery_full (charging: battery_charging_full); else `battery_<floor(p×7)>_bar` (0–6). Volume rule: muted → volume_off, ≥ 50 % volume_up, > 0 volume_down, 0 volume_mute. Weather: the data source is wttr.in `format=j1` (unchanged), whose `current_condition[0].weatherCode` is a **WWO** code, mapped onto Caelestia's icon set: 113 → clear_day (night: bedtime); 116 → partly_cloudy_day (night: partly_cloudy_night); 119, 122 → cloud; 143, 248, 260 → foggy; 176, 263, 266, 281, 284, 293–314, 353–359 → rainy; 179, 182, 185, 227, 317, 320, 323–332, 350, 362–368, 374, 377 → cloudy_snowing; 230, 335, 338, 371, 395 → snowing_heavy; 200, 386, 389, 392 → thunderstorm; unknown → cloud. Night = local time before `weather[0].astronomy[0].sunrise` or after `sunset`.
- Bar: top, all displays, **height 40** (Caelestia `innerWidth` 40), pill height 32, pill corner radius 16 (full), transparent bar background, `notch_width=188` kept. yabai `external_bar all:40:0` (Task 2 updates `apply-yabai.sh` and `selftest.sh` together).
- Launcher (Caelestia `launcher` tokens): width 600 + 2×16 padding; item height 57; max 7 rows; app icon 46 (0.8 × 57); wallpaper card 280×200, max 9 visible; panel surface opaque `surface`, top corners radius 21, anchored flush to the bottom-centre of the `visibleFrame` of the screen under the mouse; search field at the bottom (Caelestia layout: list above, search below), pill shaped, padding 14 vertical (round((12+16)/2)); placeholder text exactly `Type ">" for commands`; ≤ ~100 ms to show; no Dock icon; zero CPU when idle.

## Execution lanes (parallel)

- Task 1: done (commit 15533df).
- **Lane A (Lua bar), worktree `/home/diviyan/dotfiles-celestia-macos`, branch `rice/celestia-macos`:** Task 2 → Task 3 → Task 4.
- **Lane B (Swift launcher), worktree `/home/diviyan/dotfiles-celestia-launcher`, branch `rice/celestia-macos-launcher` from 15533df:** Task 5 → Task 6. When done, cherry-picked onto `rice/celestia-macos` (lanes touch disjoint files except `apply-yabai.sh`, different lines).
- Task 7 runs after both lanes merge. Final fix wave also covers Task 1 parked minors: `celestia-wallpaper` must exit 1 with `celestia-wallpaper: osascript failed` when setting the desktop fails, and `--current` with no state exits 1 silently.

## Review Focus

1. **No generated colours yet** (fresh Mac, or matugen failed): bar and launcher must load the committed defaults, not crash or render black. Tests: Task 2 `test_colors_fallback`, Task 5 `testPaletteFallsBackWhenMissingOrCorrupt`.
2. **Wallpaper paths with spaces/quotes/apostrophes** (`lakes-02 Lake Hawea's.jpg`): `celestia-wallpaper` must quote correctly through osascript and matugen. Test: Task 1 `test_path_with_quotes`.
3. **Display count changes** (plugging a monitor): one space item per display, rebuilt on reload. Test: Task 2 `test_spaces_one_item_per_display` with 1 and 3 stub displays.
4. **Spotify not running**: bar item hidden, popup shows `Nothing playing`, and no script launches Spotify (AppleScript must guard with `application "Spotify" is running`). Tests: Task 3 `test_spotify_not_running_hides`, Task 4 `test_popup_media_idle`.
5. **Empty results in the launcher** (no match, empty/missing wallpaper folder): empty list, Return is a no-op, no crash. Tests: Task 5 `testRankNoMatchIsEmpty`, `testScanWallpapersMissingDirIsEmpty`.

---

### Task 1: Colour pipeline and `celestia-wallpaper`

**Files:**
- Create: `macos/.config/celestia/matugen.toml`, `macos/.config/celestia/templates/colors.lua`, `macos/.config/celestia/templates/colors.json`, `macos/.config/celestia/default-colors.lua`, `macos/.config/celestia/default-colors.json`
- Create: `macos/.local/bin/celestia-wallpaper` (sh, executable)
- Modify: `macos/.config/wm/on-display-change.sh` (one line before the sketchybar reload)
- Test: `macos/tests/wallpaper/test.sh`, `macos/tests/templates/test.sh`

**Interfaces:**
- Produces: `celestia-wallpaper <file>` (sets wallpaper on every desktop, writes the absolute path to `$STATE/wallpaper`, runs matugen, then `sketchybar --reload`); `celestia-wallpaper --reapply` (re-sets the stored path on every desktop, no matugen, exit 0 silently when no state); `celestia-wallpaper --current` (prints stored path). `STATE="${CELESTIA_STATE_DIR:-$HOME/.local/state/celestia}"`. Exit 1 with `celestia-wallpaper: no such file: <path>` on stderr for a missing file. Colour files and keys as in Global Constraints.

- [ ] **Step 1: Template test.** `macos/tests/templates/test.sh` runs real local matugen 2.4.1 with `matugen.toml` (via a temp `HOME` so outputs land in `$tmp/.local/state/celestia/`) on `~/Pictures/Wallpapers/lakes-02-lake-hawea-05.jpg`, then asserts: `lua -e 'local c=dofile(arg[1]) for _,k in ipairs{...all role keys...} do assert(math.type(c[k])=="integer" and c[k]>=0xff000000, k) end' "$out/colors.lua"` passes, and `jq -e '[.primary,.on_surface,.surface_container] | all(test("^#[0-9a-f]{6}$"))' colors.json` is true and has exactly the listed keys (`jq -e 'keys|length==26'`). Run → FAIL (no config).
- [ ] **Step 2: Write `matugen.toml` + templates.** Template outputs use `~/.local/state/celestia/colors.{lua,json}` (`output_path`). Lua: `return { primary = 0xff{{colors.primary.default.hex_stripped}}, ... }`; JSON: `"primary": "{{colors.primary.default.hex}}"`. Run Step 1 → PASS.
- [ ] **Step 3: Generate the committed defaults** with the same command on lakes-02 and copy the two outputs to `default-colors.lua` / `default-colors.json`.
- [ ] **Step 4: Wallpaper tests** in `macos/tests/wallpaper/test.sh` with stubs `osascript`, `matugen`, `sketchybar` in a temp dir first on PATH, each appending its argv (one arg per line) to a log; `CELESTIA_STATE_DIR` in a temp dir:
  - `test_sets_all_then_colours`: `celestia-wallpaper "$tmp/a.jpg"` → osascript log contains `tell application "System Events" to tell every desktop to set picture to POSIX file "<abs path>"`; matugen argv = `image <abs> -t scheme-tonal-spot -m dark -c $HOME/.config/celestia/matugen.toml`; sketchybar argv `--reload`; `--current` prints the abs path; order osascript → matugen → sketchybar.
  - `test_relative_path_is_absolutised`: called from `$tmp` with `a.jpg` → state holds `$tmp/a.jpg`.
  - `test_path_with_quotes`: file `$tmp/it's "x" y.jpg` → AppleScript string has `\"` escaped quotes and the apostrophe intact; matugen gets the exact path as one argv entry.
  - `test_missing_file`: exit 1, stderr message, no stub called, state untouched.
  - `test_reapply`: with state → osascript only; without state → exit 0, nothing called.
  - `test_matugen_failure_keeps_wallpaper`: matugen stub exits 1 → script exits 1 with `celestia-wallpaper: matugen failed`, state still written, sketchybar not reloaded.
  Run → FAIL.
- [ ] **Step 5: Implement `celestia-wallpaper`** (POSIX sh, `shellcheck -s sh` clean). Escape `\` and `"` for the AppleScript string literal. Run Step 4 → PASS; `shellcheck` clean.
- [ ] **Step 6: Hook display changes.** In `on-display-change.sh`, before the sketchybar reload: `"${WM_WALLPAPER:-$HOME/.local/bin/celestia-wallpaper}" --reapply >> "$LOG" 2>&1`. `shellcheck` clean.
- [ ] **Step 7: Commit** `[DEV] Wallpaper colours pipeline`.
- On-Mac check (goes in Task 7's checklist): `celestia-wallpaper ~/Pictures/Wallpapers/forests-01*.jpg` changes every display and `~/.local/state/celestia/colors.lua` appears.

### Task 2: SbarLua bar core (look, spaces, front app, clock)

**Files:**
- Delete: `macos/.config/sketchybar/sketchybarrc` (zsh) and `macos/.config/sketchybar/plugins/{current_space,front_app,clock}.sh`; repo-root stray SbarLua files `.config/{bar,colors,default,icons,init,settings}.lua`, `.config/items/`, `.config/helpers/`.
- Create in `macos/.config/sketchybar/`: `sketchybarrc` (Lua entry), `init.lua`, `theme.lua`, `icons.lua`, `colors.lua`, `items/init.lua`, `items/spaces.lua`, `items/front_app.lua`, `items/clock.lua`
- Modify: `macos/.config/wm/apply-yabai.sh:28` and `macos/.config/wm/selftest.sh:105-107` (32 → 40)
- Test: `macos/tests/sketchybar/stub_sketchybar.lua`, `macos/tests/sketchybar/run.lua`

**Interfaces:**
- `sketchybarrc`: `#!/opt/homebrew/bin/lua`; adds `~/.local/share/sketchybar_lua/?.so` to `package.cpath` and the config dir to `package.path`; `require("init")`. `init.lua`: `sbar = require("sketchybar")` (global, SbarLua convention), `sbar.begin_config()`, bar + defaults, `require("items")`, `sbar.end_config()`, `sbar.event_loop()`.
- `theme.lua` returns `{ font = { text, numbers, icon, mono }, size = {...text sizes...}, icon_size = {small,medium,large,extra_large}, rounding = {...}, padding = {...}, anim = { curve = "tanh", small = 12, normal = 24, spatial = 30 }, bar = { height = 40, pill = 32 } }` with Global Constraints values, and `theme.font_string(family, style, size) -> "Family:Style:Size.0"`.
- `icons.lua` returns `name -> UTF-8 string` for every glyph listed in Global Constraints (keys = Material names).
- `colors.lua` returns the palette table (keys as Global Constraints) loaded via `pcall(dofile, state_path)`, falling back to `~/.config/celestia/default-colors.lua`, plus `colors.alpha(color, a) -> integer` (replace alpha byte, `a` in 0..1). Paths overridable for tests via env `CELESTIA_STATE_DIR` / `CELESTIA_CONFIG_DIR`.
- Item names later tasks rely on: `space.<display>`, `front_app`, `clock`; `items/init.lua` requires items in order; Tasks 3–4 append their requires there.
- Stub harness: `stub_sketchybar.lua` implements `add(kind, name, props)` returning an item object with `:set`, `:subscribe(events, fn)`, `:query`; `set`, `bar`, `default`, `exec(cmd, cb)`, `animate(curve, frames, fn)`, `trigger`, `begin_config/end_config/event_loop` no-ops; records everything in `stub.calls`; `exec` answers from a `stub.responses` table matched by Lua pattern (callback with parsed JSON-like Lua table when the response is a table, string otherwise — mirroring SbarLua, which hands JSON to callbacks as tables). Helpers `stub.fire(item, event, env)` call subscribed handlers. `run.lua` runs every `test_*` function, prints `ok`/`FAIL`, exits non-zero on failure.

- [ ] **Step 1: Write failing tests** in `run.lua` (each test loads a fresh `init.lua` against a reset stub):
  - `test_bar_style`: bar props `height=40, color=0x00000000, notch_width=188, display="all", sticky=true`; defaults `background.height=32, background.corner_radius=16, background.color=<surface_container>`, icon font `Material Symbols Rounded:Regular:24.0`, label font `Google Sans Flex:Regular:16.0`, label colour `on_surface`.
  - `test_spaces_one_item_per_display`: `yabai -m query --displays` stub returns 1 then 3 displays → items `space.1` (resp. `space.1..3`) with `display=<n>`.
  - `test_space_label_to_number`: visible space label `three` on display 2 → `space.2` icon `"3"` in `Rubik:Medium:18.0`, colour `on_primary`, background `primary`; unlabeled index 7 → `"7"`; space change animates (`animate("tanh", 30, ...)`).
  - `test_front_app`: event `front_app_switched` with `INFO="kitty"` → label `kitty` colour `primary` font `Google Sans Flex:Regular:16.0`; icon `terminal`; `Slack` → `chat`; unknown → `desktop_windows`.
  - `test_clock`: icon = calendar_month glyph, icon+label colour `tertiary`, label font size 18, `update_freq=10`, label = output of `date '+%a %b %-d %-H:%M'` (stubbed).
  - `test_colors_fallback`: state file missing → `primary` equals default file's; state file containing `syntax error(` → defaults; valid state → state values.
  - `test_space_click_reloads`: `mouse.clicked` on a space item → `exec("sketchybar --reload")` (keeps today's behaviour).
  Run `lua5.4 macos/tests/sketchybar/run.lua` → FAIL.
- [ ] **Step 2: Implement** the files above. Port behaviour from the deleted plugins (read them first with `git show origin/macos:<path>`): spaces query `yabai -m query --spaces --display <n>`, visible space, label→number map incl. `eleven`, events `space_change display_change system_woke` + `mouse.clicked`; front app via `front_app_switched`; clock format unchanged. App→icon map (by app name, case-insensitive): kitty/Terminal/iTerm2 → terminal; Safari/Google Chrome/Firefox/Arc → web; Code/Cursor/IntelliJ IDEA/PyCharm/Xcode → code; Slack/Discord/Microsoft Teams/WhatsApp/Messages → chat; Mail/Outlook → mail; Spotify/Music → music_note; Finder → folder; System Settings → settings; else desktop_windows. Space change and clock popup use `sbar.animate(theme.anim.curve, ...)`.
- [ ] **Step 3: Run tests** → all `ok`; `luac5.4 -p` every `.lua`; `luajit` not used.
- [ ] **Step 4: Bar height in yabai**: `apply-yabai.sh` `external_bar all:40:0`, `selftest.sh` expects `all:40:0`. `shellcheck` clean.
- [ ] **Step 5: Delete** the three ported plugins, the zsh `sketchybarrc`, and the stray root `.config` SbarLua files listed above. Remaining plugins stay until Task 3.
- [ ] **Step 6: Commit** `[DEV] SketchyBar in Lua with Caelestia style`.

### Task 3: Status items (Spotify, attention, weather, battery, volume, mail, Discord, pomodoro)

**Files:**
- Create in `macos/.config/sketchybar/items/`: `spotify.lua`, `attention.lua`, `weather.lua`, `battery.lua`, `volume.lua`, `mail.lua`, `discord.lua`, `pomodoro.lua`; modify `items/init.lua`
- Delete: the corresponding `plugins/*.sh` once ported (`keyboard.sh` too if unused by the old rc — it was not referenced; delete). Data-heavy AppleScript/curl may stay in `macos/.config/sketchybar/scripts/<name>.sh` printing plain data (one value per line or JSON) that Lua parses; no script calls `sketchybar` itself.
- Test: extend `macos/tests/sketchybar/run.lua`

**Interfaces:**
- Consumes: Task 2 `theme`, `icons`, `colors`, stub harness, `items/init.lua`.
- Produces: item names `spotify`, `attention`, `weather`, `battery`, `volume`, `mail`, `discord`, `pomodoro`; `weather.lua` exports `weather.current(cb)` → `cb({ icon = <glyph>, temp = "<n>°C", desc = <string>, location = <string>, moon = <moon_phase string> } | nil)`; `spotify.lua` exports `spotify.state(cb)` → `cb({ running = bool, playing = bool, artist, title } )`. Task 4's popup reuses both.
- Layout: left = spaces, front_app, spotify, attention; right (in order from the edge) = clock, battery, volume, mail, discord, pomodoro, weather. Status items (battery, volume, mail, discord, pomodoro) are grouped in one `bracket` named `status` with `surface_container` background (Caelestia `StatusIcons` pill), icons `secondary`.

- [ ] **Step 1: Failing tests**, one per item, each with stubbed exec responses copied from what the old plugin parsed:
  - `test_spotify_not_running_hides`: state `running=false` → `drawing=false`; the AppleScript command string contains `application "Spotify" is running`.
  - `test_spotify_playing`: label `Artist — Title`, icon music_note, colour `primary`; click → `exec` of the Spotify playpause AppleScript.
  - `test_battery_levels`: 100 % AC → battery_full; 100 % charging → battery_charging_full; 50 % → battery_3_bar; 15 % discharging → colour `error`; 15 % charging → `secondary`.
  - `test_volume_icons`: muted → volume_off; 60 → volume_up; 20 → volume_down; 0 → volume_mute; label `<n>%`; scroll/click behaviour as the old plugin.
  - `test_weather_codes`: WWO 113 at 14:00 → clear_day; 113 at 23:00 (sunset 17:30) → bedtime; 116 night → partly_cloudy_night; 302 → rainy; 338 → snowing_heavy; 248 → foggy; 389 → thunderstorm; 999 → cloud; fetch failure → item keeps last value (no blank). The old separate `weather.moon` item is dropped (moon phase moves to the dashboard).
  - `test_mail_discord_counts`: count 0 → `drawing=false`; 3 → label `3`, icons mail / forum.
  - `test_pomodoro_state`: reads/writes `$HOME/.config/sketchybar/.pomodoro_state` with the same format and phases as the old plugin (`<epoch> focus|break`); icon timer during focus, coffee during break.
  - `test_attention`: event `window_attention_changed` with attention windows → `drawing=true`, background `error`, icon notifications in `on_error`; none → hidden.
  Run → FAIL.
- [ ] **Step 2: Implement**, porting commands verbatim from `git show origin/macos:macos/.config/sketchybar/plugins/<name>.sh` (same update_freq, events — `spotify_change` = `com.spotify.client.PlaybackStateChanged`, `window_attention_changed`, `volume_change`, `system_woke` — and click actions). Run → PASS, `luac5.4 -p` and `shellcheck` on any kept script.
- [ ] **Step 3: Commit** `[DEV] Bar status items`.

### Task 4: Clock dashboard popup

**Files:**
- Create: `macos/.config/sketchybar/items/dashboard.lua`; modify `items/init.lua`, `items/clock.lua` (click toggles popup)
- Test: extend `macos/tests/sketchybar/run.lua`

**Interfaces:**
- Consumes: `weather.current`, `spotify.state` (Task 3), Task 2 modules.
- Produces: popup items under `clock`: `dashboard.date` (title.small 19 Medium, `on_surface`, e.g. `Monday 16 November`), `dashboard.calendar.<n>` (one popup item per line of `cal -h` output — month header + weekday row + week rows — mono.small 16, `on_surface_variant`; the week row containing today uses `primary`), `dashboard.weather` (weather icon icon.large 32 `primary` + `<temp> · <desc> · <moon>` body.medium), `dashboard.media` (music_note + `Artist — Title` or `Nothing playing`), `dashboard.prev`, `dashboard.playpause`, `dashboard.next` (icon.medium 24, `on_surface`; play_arrow when paused, pause when playing). Popup background `surface`, corner radius 21, padding 16, border none.

- [ ] **Step 1: Failing tests**:
  - `test_popup_toggle`: click on `clock` → `popup.drawing="toggle"` and contents refreshed (calls `weather.current`, `spotify.state`, `cal`); `mouse.exited.global` on clock → `popup.drawing=false`.
  - `test_popup_style`: popup background colour `surface`, `corner_radius=21`; date label font `Google Sans Flex:Medium:19.0`; calendar font `CaskaydiaCove Nerd Font Mono:Regular:16.0`.
  - `test_popup_media_idle`: Spotify not running → media label `Nothing playing`, prev/playpause/next `drawing=false`.
  - `test_popup_controls`: playing → playpause icon = pause glyph; clicks run Spotify `previous track` / `playpause` / `next track` AppleScripts (guarded by `is running`).
  - `test_popup_weather_missing`: `weather.current` yields nil → weather row `drawing=false`.
  Run → FAIL.
- [ ] **Step 2: Implement.** Run → PASS; `luac5.4 -p`.
- [ ] **Step 3: Commit** `[DEV] Clock dashboard popup`.

### Task 5: `LauncherCore` Swift library

**Files:**
- Create: `macos/launcher/Package.swift` (swift-tools-version 5.9; products: library `LauncherCore`, executable `celestia-launcher`; platforms `.macOS(.v13)`), `macos/launcher/Sources/LauncherCore/{Fuzzy.swift,AppCatalog.swift,Wallpapers.swift,Mode.swift,Palette.swift}`, `macos/launcher/Sources/celestia-launcher/main.swift` (temporary: whole body inside `#if canImport(AppKit)`, `#else` prints `celestia-launcher: macOS only` and exits 1 — Task 6 fills the AppKit part), `macos/launcher/Tests/LauncherCoreTests/*.swift`
- Modify: `.gitignore` (add `macos/launcher/.build/`)

**Interfaces (Foundation only, no AppKit):**
- `public struct AppEntry: Equatable, Sendable { public let name: String; public let url: URL }`
- `public func scanApplications(roots: [URL]) -> [AppEntry]` — recursive, collects `*.app` directories without descending into them, name = bundle filename without `.app`, de-duplicated by name (first root wins), sorted by `localizedStandardCompare`. Missing roots ignored.
- `public func fuzzyScore(_ query: String, _ candidate: String) -> Int?` — case- and diacritic-insensitive subsequence match; `nil` if not a subsequence; `""` scores 0. Higher is better: prefix match > word-start matches > consecutive runs > scattered.
- `public func rank(_ query: String, _ apps: [AppEntry], limit: Int = 7) -> [AppEntry]` — by score desc, then shorter name, then alphabetical; empty query → first `limit` alphabetically.
- `public enum LauncherMode: Equatable { case apps(String), commands(String), wallpapers(String) }`; `public func parseMode(_ text: String) -> LauncherMode` — `">wallpaper"` or `">wallpaper <q>"` → `.wallpapers(q)` (trimmed); other text starting with `>` → `.commands(rest)`; else `.apps(text)`. `public let launcherCommands = ["wallpaper"]`.
- `public func scanWallpapers(in dir: URL) -> [URL]` — flat, extensions jpg/jpeg/png/heic case-insensitive, sorted by filename; missing dir → `[]`.
- `public func rankWallpapers(_ query: String, _ files: [URL]) -> [URL]` — fuzzy on filename, keeps scan order for empty query.
- `public struct RGB: Equatable { public let r, g, b: Double }` (0…1); `public struct Palette { public subscript(role: String) -> RGB }` (missing role → magenta 1,0,1 so mistakes are visible); `public func loadPalette(primary: URL, fallback: URL) -> Palette` — tries primary JSON, then fallback; both failing → built-in neutral grey palette.
- `public func thumbnailURL(for wallpaper: URL, cacheDir: URL) -> URL` → `cacheDir/<filename>.jpg`; `public func thumbnailIsStale(thumb: URL, source: URL) -> Bool` (missing thumb or older mtime).

- [ ] **Step 1: Failing tests** (`XCTest`):
  - `testScanFindsNestedAppsNotInsideBundles`: temp tree `A/Safari.app/Contents/Foo.app`, `A/Utilities/Terminal.app`, `B/Safari.app` → `[Safari(A), Terminal]`.
  - `testFuzzyBasics`: `fuzzyScore("", "Safari") == 0`; `fuzzyScore("xyz","Safari") == nil`; `fuzzyScore("SAF","safari") != nil`; `fuzzyScore("e","É") != nil`.
  - `testRankPrefersPrefixAndWordStart`: `rank("sl", [Calendar, Mail, Slack]).first?.name == "Slack"`; `rank("vsc", [Avast Security Center, Visual Studio Code]).first?.name == "Visual Studio Code"`; `rank("mail", [Mailspring, Mail]).first?.name == "Mail"`.
  - `testRankNoMatchIsEmpty`: `rank("qqq", apps).isEmpty`; `testRankLimit` 7.
  - `testParseMode`: `""`→`.apps("")`; `"saf"`→`.apps("saf")`; `">"`→`.commands("")`; `">wa"`→`.commands("wa")`; `">wallpaper"`→`.wallpapers("")`; `">wallpaper  lake "`→`.wallpapers("lake")`.
  - `testScanWallpapersFiltersAndSorts`: files `b.JPG, a.png, c.heic, d.txt, sub/e.jpg` → `[a.png, b.JPG, c.heic]`; `testScanWallpapersMissingDirIsEmpty`.
  - `testPaletteParsesHex`: `{"primary":"#ff8000"}` → `RGB(1, 128/255, 0)`.
  - `testPaletteFallsBackWhenMissingOrCorrupt`: primary missing → fallback values; primary `"{"` → fallback; both missing → neutral palette, no throw.
  - `testThumbnailStaleness`: missing thumb → stale; thumb newer than source → not stale.
  Run: `docker run --rm --user "$(id -u):$(id -g)" -e HOME=/tmp -v "$PWD/macos/launcher":/src -w /src swift:6.0-jammy swift test` → FAIL (compile errors).
- [ ] **Step 2: Implement.** Run the same command → all pass.
- [ ] **Step 3: Commit** `[DEV] Launcher core`.

### Task 6: Launcher app, toggle, LaunchAgent, skhd bind

**Files:**
- Modify: `macos/launcher/Sources/celestia-launcher/main.swift`; create `macos/launcher/Sources/celestia-launcher/{LauncherPanel.swift,Theme.swift,ResultsView.swift,Thumbnails.swift}` (all wrapped in `#if canImport(AppKit)`)
- Create: `macos/launcher/install.sh`, `macos/Library/LaunchAgents/local.celestia.launcher.plist`
- Modify: `.skhdrc` (add one bind), `macos/.config/wm/apply-yabai.sh` (one rule line, next to the other app rules, before `rule --apply`)
- Test: Linux build still passes (`swift build` in Docker compiles the stub); `plutil`-equivalent check `python3 -c 'import plistlib,sys; plistlib.load(open(sys.argv[1],"rb"))'`; `shellcheck install.sh`.

**Interfaces:**
- Consumes: all of Task 5; `celestia-wallpaper <file>` (Task 1); palette files (Task 1).
- CLI: `celestia-launcher serve` (resident: `NSApplication` with `.accessory` policy, observes `DistributedNotificationCenter` name `local.celestia.launcher.toggle`), `celestia-launcher toggle` (posts that notification with `deliverImmediately: true`, exits 0). App list scanned at start and re-scanned on each show in the background (show uses the cached list immediately).
- `Theme.swift`: font families, sizes, radii, paddings from Global Constraints (single source); `Theme.font(_ family:, size:, weight:) -> NSFont` falls back to `.systemFont` if the family is missing.

- [ ] **Step 1: Implement the panel** (`NSPanel` subclass, borderless, `canBecomeKey = true`, level `.floating`, `collectionBehavior [.canJoinAllSpaces, .fullScreenAuxiliary]`, `hidesOnDeactivate` false; closes on `windowDidResignKey` and Esc). Layout and look exactly per Global Constraints "Launcher": results list (rows: icon 46 via `NSWorkspace.shared.icon(forFile:)`, name body.medium 19 `on_surface`, path-derived subtitle body.small 16 `outline`; selected row = `on_surface` @ 8 % with radius 12, slides 200 ms), search field pill `surface_container` with search glyph icon 22 `on_surface_variant` at left padding 16, placeholder `Type ">" for commands`. Keys: typing filters, ↑/↓ (and Tab/Shift-Tab) move, Return opens (`NSWorkspace.shared.openApplication(at:configuration:)`) and hides; in `.commands` Return replaces text with `">wallpaper "`; in `.wallpapers` the list becomes a horizontal row of up to 9 cards 280×200 (thumbnail aspect-fill radius 12, filename label.medium 16 below, selected card full opacity, others 0.6 — ←/→ also move), Return runs `~/.local/bin/celestia-wallpaper <path>` via `Process` and hides; no results → centred `No results` body.large 21 `on_surface_variant` with Return a no-op. On show: reload palette (`~/.local/state/celestia/colors.json`, fallback `~/.config/celestia/default-colors.json`), place on screen under `NSEvent.mouseLocation`, clear text, activate, fade/slide in 200 ms.
- [ ] **Step 2: Thumbnails**: generate missing/stale thumbs (Task 5 helpers) on a background queue into `~/.cache/celestia/thumbs/` as JPEG at 560×400 px (2× of 280×200); show `image` glyph placeholder `outline` until ready. App icons: in-memory `[String: NSImage]` cache keyed by bundle path, pre-warmed in the background after each app scan, so showing the panel never loads icons synchronously.
- [ ] **Step 3: `install.sh`**: `swift build -c release --package-path "$(dirname "$0")"`, copy the binary to `~/.local/bin/celestia-launcher`, then `launchctl bootout gui/$(id -u)/local.celestia.launcher 2>/dev/null; launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/local.celestia.launcher.plist`. `set -eu`, shellcheck clean.
- [ ] **Step 4: LaunchAgent plist**: Label `local.celestia.launcher`, ProgramArguments `/bin/sh -c 'exec "$HOME/.local/bin/celestia-launcher" serve'`, RunAtLoad true, KeepAlive true, ProcessType `Interactive`, stdout/stderr to `/tmp/celestia-launcher.log`.
- [ ] **Step 5: skhd**: add `cmd - space : $HOME/.local/bin/celestia-launcher toggle` in the apps section of `.skhdrc`; no other line changes (`git diff .skhdrc` shows exactly one added line plus at most one comment line).
- [ ] **Step 5b: yabai rule** so the panel is never tiled or dimmed: `"$YABAI" -m rule --add label=celestia-launcher app="^celestia-launcher$" manage=off opacity=1.0` (follow the file's existing rule style/variables). `shellcheck` clean.
- [ ] **Step 6: Verify on Linux**: Docker `swift build` and `swift test` pass (AppKit code is compiled out); plist parses; shellcheck clean. Note in the report which code paths could not be compiled.
- [ ] **Step 7: Commit** `[DEV] Celestia launcher app`.

### Task 7: Shortcuts, setup notes, stow ignores, checklist

**Files:**
- Create: `macos/SHORTCUTS.md`, `macos/README.md`, `macos/.stow-local-ignore`

- [ ] **Step 1: `macos/.stow-local-ignore`**: the stow default list (copy from root `.stow-local-ignore`) plus `\.DS_Store`, `^/README.*`, `^/SHORTCUTS.md`, `^/launcher`, `^/tests`. Verify on Linux: `stow -n -v -d . -t "$(mktemp -d)" macos 2>&1` lists none of those paths (install `stow` check: if missing, skip and say so).
- [ ] **Step 2: `SHORTCUTS.md`**: tables grouped Windows / Spaces / Apps / Launcher / Bar, generated by reading `.skhdrc` line by line (every bind, keycodes translated to the key labels used in its comments) plus launcher keys (Return, Esc, ↑/↓, Tab, `>wallpaper`) and bar mouse actions (click space = reload bar, click clock = dashboard, click Spotify = play/pause, volume scroll/click, mail/Discord click, pomodoro click). Rule at the top: update this file with every bind change.
- [ ] **Step 3: `README.md`** setup in order: `brew install lua jq rust` (+ existing yabai/skhd/sketchybar); SbarLua (`git clone https://github.com/FelixKratz/SbarLua.git /tmp/SbarLua && (cd /tmp/SbarLua && make install) && rm -rf /tmp/SbarLua`); `cargo install matugen --locked --version 2.4.1`; fonts `brew install --cask font-google-sans-flex font-rubik font-material-symbols font-caskaydia-cove-nerd-font`; Xcode CLT (`xcode-select --install`); `stow .` + `stow -t ~ macos`; copy wallpapers to `~/Pictures/Wallpapers`; System Settings: disable Spotlight Cmd+Space, Wallpaper → "Show on all Spaces"; `macos/launcher/install.sh`; `celestia-wallpaper ~/Pictures/Wallpapers/lakes-02-lake-hawea-05.jpg`; `brew services restart sketchybar`; `skhd --restart-service`; `~/.config/wm/apply-yabai.sh`. Then the **on-Mac verification checklist**, one checkbox per deliverable: bar on every display at 40 pt, no window under it, nothing behind the notch, space number per display updates on Cmd+N and on moving a space; fonts render (Rubik number, Material icons not tofu); each status item; clock popup content and controls; `celestia-wallpaper` recolours bar; launcher opens < 100 ms on Cmd+Space on the screen under the mouse, finds Utilities apps, `>wallpaper` thumbnails + apply; Activity Monitor shows ~0 % CPU idle for `celestia-launcher`; `~/.config/wm/selftest.sh` passes.
- [ ] **Step 4: Commit** `[DEV] macOS shortcuts and setup notes`.
