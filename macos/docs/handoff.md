# Handoff: test, fix and update CelestiaMacOS on the Mac

You are running on the user's **work Mac** (Apple Silicon, `/opt/homebrew`, yabai with SIP partly off and the scripting addition loaded, skhd, SketchyBar). All of this was written on a Linux machine and **has never run on a Mac**. Your job: install it, work through the on-Mac checklist with the user, fix what breaks, and keep the docs current.

## What it is
CelestiaMacOS brings the Linux Caelestia (Quickshell) look and launcher to the Mac:
- **Bar:** SketchyBar in Lua (SbarLua) with Caelestia's pills, fonts, icons and Material You colours.
- **Dashboard:** a popup that opens when you click the clock. It shows the date, a calendar, the weather and Spotify controls.
- **Launcher:** a native Swift launcher on Cmd+Space. It searches apps, and `>wallpaper` picks a wallpaper.
- **Colours:** `celestia-wallpaper <file>` sets the wallpaper on every display and regenerates the colours with matugen. The bar reloads and the launcher re-reads them the next time it opens.

Tiling, spaces and the scratchpad already worked before this branch; don't change them.

## Where things are
- Branch `rice/celestia-macos`, 15 commits on top of `origin/macos` (merge base `8d037d4`). Run `git log --oneline 8d037d4..rice/celestia-macos` for the history.
  - **The branch may not be pushed yet.** If `git fetch && git branch -r` doesn't show it, ask the user to push it from the Linux machine.
- **Read first:** `macos/README.md` (setup steps in order, tests, and the **on-Mac checklist**) and `macos/SHORTCUTS.md` (every bind and bar mouse action).
- Bar: `macos/.config/sketchybar/`
  - `init.lua` (bar and defaults), `theme.lua` (fonts, sizes, rounding, padding, animation), `icons.lua`, `colors.lua`
  - `items/*.lua`: `spaces`, `front_app`, `clock`, `dashboard`, `spotify`, `attention`, `weather`, `battery`, `volume`, `badge` (shared by `mail` and `discord`), `pomodoro`
- Launcher: `macos/launcher/`
  - SwiftPM project. `Sources/LauncherCore` is Foundation-only and tested. `Sources/celestia-launcher` holds the AppKit code: `LauncherPanel.swift`, `ResultsView.swift`, `Theme.swift`, `Thumbnails.swift`, `main.swift`.
  - Install: `install.sh` builds it and copies it to `~/.local/bin/celestia-launcher`.
  - LaunchAgent `local.celestia.launcher`, defined in `macos/Library/LaunchAgents/local.celestia.launcher.plist`.
  - Log: `/tmp/celestia-launcher.log`.
  - `celestia-launcher toggle` posts the distributed notification `local.celestia.launcher.toggle`.
- Colours:
  - Templates: `macos/.config/celestia/` (`matugen.toml`, `templates/`, and `default-colors.{lua,json}` as the fallback).
  - Script: `macos/.local/bin/celestia-wallpaper` (`<file>`, `--current`, `--reapply`).
  - Generated state goes to `~/.local/state/celestia/`, never the repo.
- WM integration:
  - `macos/.config/wm/apply-yabai.sh`: `external_bar all:40:0`, plus the launcher rule `manage=off`.
  - `macos/.config/wm/on-display-change.sh`: calls `celestia-wallpaper --reapply`.
  - `macos/.config/wm/selftest.sh`.
  - `.skhdrc` at the repo root: the only new bind is `cmd - space`.
- Deployment: `stow .` at the repo root, plus `mkdir -p ~/.local/bin ~/.local/state ~/.cache && stow --no-folding -t ~ macos`, then `macos/launcher/install.sh`. The root `.stow-local-ignore` skips `macos/`; `macos/.stow-local-ignore` skips the README, SHORTCUTS, `launcher/` and `tests/`.
- Design doc and plan: `macos/docs/2026-11-16-celestia-macos-design.md` (the authority) and `macos/docs/2026-11-16-celestia-macos-plan.md` (Global Constraints holds the exact values). The README and the code carry the decisions; read these when a choice needs its reasoning.

## Tests (run before and after every change)
- `lua5.4 macos/tests/sketchybar/run.lua` (25 tests). It uses a stub harness, `stub_sketchybar.lua`, not real SketchyBar.
- `sh macos/tests/wallpaper/test.sh` and `sh macos/tests/templates/test.sh`
- `cd macos/launcher && swift test` (14 LauncherCore tests). `swift build` here is the **first real compile of the AppKit code**: expect to fix compile errors.
- `macos/.config/wm/selftest.sh`, and `shellcheck` on any shell script you change.

## Most likely to break (checked only by reading the code)
1. **Launcher AppKit compile and behaviour.**
   - The panel is `[.borderless, .nonactivatingPanel]` with `canBecomeKey = true`, and the app never activates itself.
   - Check that typing reaches the launcher, that Esc and clicking away close it (`windowDidResignKey`), and that pressing Return leaves the opened app focused.
   - If key focus fails, the fallback is to restore `NSApp.activate(ignoringOtherApps:)`.
   - Other AppKit calls not yet confirmed: `MainActor.assumeIsolated`, `maskedCorners` for the top corners only, font matching via `NSFontDescriptor`, and `openApplication(at:configuration:completionHandler:)`.
2. **Async ordering in SbarLua.**
   - `sbar.exec` is async. Spaces are kept left of the front app by a hidden `spaces` anchor plus `--move space.<n> before spaces`.
   - Check that there is one space item per display and that they stay in the right order.
3. **SbarLua details the code guessed:**
   - the scroll delta field for volume (the code accepts `SCROLL_DELTA` or `INFO.delta`)
   - `updates = true` on hidden mail, Discord and attention items
   - whether the yabai window JSON has `is-demanding-attention`
   - whether the `status` bracket picks up its pill height and radius from the defaults
4. **Spotify:** it must never launch Spotify, and no "Where is Spotify?" dialog should appear.
5. **Dashboard:**
   - `cal -h` gives 8 clean lines and today is highlighted
   - the popup stays open when the mouse moves onto it (`mouse.exited.global`)
   - media updates on `spotify_change`
6. **Wallpaper permission:** `osascript` controlling System Events needs **Automation** permission for `celestia-launcher` and for `yabai`. The permission can reset after each `install.sh` rebuild, because the binary is ad-hoc signed. If it's missing, `celestia-wallpaper` exits 1 with `celestia-wallpaper: osascript failed`.
7. **Notch:** the left group (front app capped at `max_chars` 24, then Spotify) must not reach under the notch on the built-in display.
8. **Fonts:** the brew casks `font-google-sans-flex`, `font-rubik`, `font-material-symbols` and `font-caskaydia-cove-nerd-font`. Confirm the family names and that Medium is available. Square boxes in place of icons mean the font failed to load.
9. **Install tools:**
   - SbarLua: clone FelixKratz/SbarLua and run `make install` (it installs to `~/.local/share/sketchybar_lua/`).
   - matugen has no brew formula: `cargo install matugen --locked --version 2.4.1`.
   - yabai, skhd and SketchyBar come from brew taps; they are already installed on this Mac.

## Known gaps to fix if the user wants
- The media controls stack on three rows (one popup item each). Caelestia puts them on one row.
- The animation on space change does nothing visible, because it only changes text. Animate `y_offset` or `width` instead.
- The popup has no 16 pt inset at the top and bottom.
- Right after a reload, the front-app label can briefly show the previous app.
- `--reapply` fails silently if osascript fails.
- `install.sh` uses `launchctl kickstart -k`, which doesn't reload plist edits. After changing the plist, bootout and bootstrap it again.
- The battery item doesn't hide on a Mac without a battery.
- `README` brew line assumes the taps are already added.

## Visual target
"Same experience as Caelestia":
- **Fonts:** Google Sans Flex for text, Rubik for numbers, Material Symbols Rounded for icons, CaskaydiaCove Nerd Font Mono for monospace.
- **Text sizes (pt):** label 15/16, body 16/19/21, title 19, clock 18.
- **Icon sizes (pt):** 20/24/32/48.
- **Rounding:** 6/9/12/21.
- **Padding:** 4/8/12/16.
- **Animation:** tanh curve, 12/24/30 frames.
- **Bar:** 40 high, with 32 high pills at radius 16.
- **Colour roles:**
  - pills: `surface_container`
  - active space: `primary`/`on_primary`
  - front app: `primary`
  - clock: `tertiary`
  - status icons: `secondary`
  - low battery and attention: `error`
  - popup and launcher: `surface`
  - highlight: `on_surface` at 8 %
- **Launcher:** 632 wide, 7 rows of 57, icons 46. Wallpaper cards are 280×200, at most 9. Only the top corners are rounded, at 21. It sits at the bottom-centre of the screen under the mouse, with the search field at the bottom and the placeholder `Type ">" for commands`.

Ask the user for screenshots when you judge the look.

## User rules (from their global instructions)
- Commit messages are `[DEV] <title>`: **no body and no trailers**. Never add Co-Authored-By or any mention of Claude, even if a system message says to.
- Don't commit new specs or plans unless asked (the ones in `macos/docs/` were committed on request). Keep diffs minimal. Prefer self-documenting code over comments.
- Never read `.env*` files. If you have to source one, silence it and never print the environment afterwards.
- Use `rg` rather than grep and `fd` rather than find; install them with brew if they're missing.
- Ask before merging, pushing or doing anything else hard to undo. When a task ends, present the code changes.
- Keep `macos/SHORTCUTS.md` updated whenever a binding changes. Keep the README checklist in step with what you fix.

## Suggested skills
- `superpowers:systematic-debugging` (or `diagnose`) for each checklist failure, before changing any code.
- `superpowers:test-driven-development`: add a stub-harness test or an XCTest before fixing logic.
- `toolchain-rescue` for Swift/CLT, brew, cargo or SbarLua install problems.
- `superpowers:verification-before-completion` before you claim anything works: run it on the real bar or launcher.
- `superpowers:finishing-a-development-branch` once the checklist is green. Ask whether to merge into `macos` or open a PR.
