# CelestiaMacOS: Caelestia look and launcher on the work Mac — design

## Intent
The user's work computer is a Mac running yabai. On Linux they now have the Caelestia
Quickshell desktop (Material You colours from a nature wallpaper, rounded floating
surfaces, a fast launcher). They want the Mac to feel the same. What they miss most on
the Mac is **the look and feel, and the launcher**. Tiling, spaces and scratchpad already
work on the Mac and are not the problem.

## Starting point (branch `origin/macos`, last commit 2026-11-13)
- yabai with SIP partly off and the scripting addition loaded (`sudo yabai --load-sa`),
  bsp layout, 10 labelled spaces `one`..`ten` plus a hidden `eleven` for the scratchpad.
- `.yabairc`, `.skhdrc` at repo root. `macos/.config/wm/*.sh`: profile (pure helpers),
  apply-yabai (labels, gaps per display UUID, external_bar `all:32:0`, app→space rules),
  focus/move scripts, display-change hook, selftest.
- skhd (Cmd-based): Cmd+arrows focus, Cmd+Shift+arrows move window, Cmd+Ctrl+Shift+arrows
  move space to display, Cmd+1..0 focus space, Cmd+Shift+1..0 move window to space,
  Cmd+Return kitty, Cmd+Tab scratchpad (`scratchpad --toggle kitty`), Ctrl+F zoom,
  Ctrl+Shift+Space bsp/stack, Ctrl+Alt+Cmd+R restart yabai.
- SketchyBar, shell config `macos/.config/sketchybar/sketchybarrc` + `plugins/*.sh`:
  top bar on all displays, height 32, notch_width 188, JetBrainsMono Nerd Font, hard-coded
  Catppuccin-ish colours. Items: per-display current space, front app, Spotify, attention,
  weather (+moon), clock, battery, volume, mail, Discord, pomodoro.
- Leftovers to ignore: AeroSpace config (`.config/aerospace*`), and a SbarLua bar dropped
  loose in `.config/` (`init.lua`, `bar.lua`, `colors.lua`, `items/`, `helpers/`…).

## Goals
1. **Caelestia look for the bar.** Rebuild the SketchyBar config in its Lua API (SbarLua)
   with Caelestia's visual language: floating rounded "pill" groups on a transparent bar,
   Material 3 tonal colours from the wallpaper, Rubik for text, Material Symbols Rounded
   for icons, short eased animations (SketchyBar `--animate`). Keep the bar on every
   display, and keep the existing information (space number per display, front app,
   Spotify, attention, weather, clock, battery, volume, mail, Discord, pomodoro).
2. **Dashboard as bar popups.** Clicking the clock opens a popup with date/calendar,
   weather and media (Spotify now playing + play/pause/next/prev). Styled like the bar.
3. **Custom native launcher** ("Celestia launcher"): a lightweight Swift app with one
   floating, blurred, rounded panel. Fuzzy-search and launch apps (`/Applications`,
   `/System/Applications`, `~/Applications`, incl. subfolders like Utilities). Keyboard
   only: type, ↑/↓, Return to open, Esc to close; closes on focus loss. `>wallpaper`
   mode lists the wallpaper folder with thumbnails and applies the chosen one
   (mirrors Caelestia's `>wallpaper`). Coloured from the same generated scheme.
   Opens instantly (stays resident, no Dock icon, toggled from skhd).
4. **Wallpaper → colours.** The same 24 nature wallpapers (forests, mountains, lakes)
   live in `~/Pictures/Wallpapers` on the Mac. One command sets the wallpaper on all
   displays and regenerates the Material You scheme (matugen, `scheme-tonal-spot`,
   dark), which recolours the bar (reload) and the launcher (re-read on next open).
5. **One shortcuts file.** A single human-readable list of every shortcut and what it
   does, kept next to the config and updated with every bind change.

## Non-goals
- Replacing macOS notifications (keep Notification Center as is).
- Vertical bar (SketchyBar only draws top/bottom bars).
- Changing tiling behaviour, space layout, scratchpad, display handling or the existing
  wm scripts, except where the bar integration requires it.
- AeroSpace anything. Raycast/Alfred/Hammerspoon.
- Theming kitty, nvim, Slack, Teams, Discord etc. from the wallpaper (shell-only colours,
  same rule as on Linux).
- Window borders (JankyBorders): Linux runs with no borders; keep parity.
- Lock screen, idle, session menu (macOS handles these).
- Committing wallpapers to the repo.

## Anti-goals
- Any existing skhd shortcut changes key or function.
- The launcher using noticeable CPU/RAM while idle, or taking >~100 ms to appear.
- Bar regressions: lost per-display space number, items on the wrong display, bar hidden
  behind the notch, or yabai windows overlapping the bar.
- Anything that requires a reboot or re-disabling SIP beyond today's setup.

## Constraints
- **Built from a Linux machine.** Nothing can be run or compiled here; every deliverable
  needs an explicit on-Mac verification step the user runs. Keep custom code small.
- macOS on Apple Silicon (`/opt/homebrew`), yabai + SA, skhd, SketchyBar, kitty, jq.
- SIP partly disabled is accepted and required.
- New tools allowed via Homebrew: `sketchybar` SbarLua module, `matugen`, fonts
  (Rubik, Material Symbols Rounded). Swift via Xcode Command Line Tools (no Xcode project
  required).
- Deployment on the Mac (user-confirmed): repo root via `stow .`, plus `macos/` as its own
  stow package via `stow -t ~ macos` (so `macos/.config/X` → `~/.config/X`). All new
  macOS files go under `macos/` and install the same way.
- Work on a new branch `rice/celestia-macos` created from `origin/macos`. Commit style
  `[DEV] <title>`, no body, no co-author trailers. Specs/plans are not committed.

## Approaches considered
- **A. Restyled SketchyBar (Lua) + popups for the dashboard + small native Swift
  launcher + matugen colours (chosen).** Reuses what works, puts effort in the look and
  the launcher, limits untested new code to the launcher. Trade-off: the bar's look is
  bounded by what SketchyBar can draw.
- B. Hammerspoon launcher/dashboard + SketchyBar. Its chooser looks plain; a Caelestia
  look needs an HTML webview: heavier, less native. Rejected (launcher must be light).
- C. One custom Swift app drawing bar, launcher and dashboard (Quickshell-like). Closest
  look, by far the most code, all untestable from here. Rejected.

## Decided
- Approach A.
- Branch `rice/celestia-macos` from `origin/macos`. AeroSpace files ignored (left as is).
- Launcher is custom and native (not Raycast). Keybind: **Cmd+Space** (same position as
  Super+Space on Linux; user confirmed it is free on the work Mac); the user disables
  Spotlight's Cmd+Space in System Settings (documented setup step).
- Generated colours (assistant's call): matugen writes to `~/.local/state/celestia/`
  (`colors.lua`, `colors.json`), never into the repo. The repo ships a committed default
  palette (dark tonal-spot from one of the wallpapers) that the bar and launcher fall back
  to until the first `celestia-wallpaper` run.
- Bar migration (assistant's call): the shell `sketchybarrc` + `plugins/*.sh` are replaced
  outright by the Lua config (git history is the rollback). SbarLua install is a setup
  step. Plugins whose logic is easier in shell (Spotify/weather AppleScript and curl) may
  stay as scripts called from Lua items.
- Dashboard popup content (assistant's call): text plus controls: date + month calendar,
  current weather (same ipinfo.io + wttr.in source as today, which already works on the
  work network), Spotify artist/title with play-pause/next/prev. Album art only if
  SketchyBar's image support makes it cheap; not required.
- Wallpaper scope (assistant's call): `celestia-wallpaper <file>` sets the picture on every
  connected display; spaces follow via macOS "Show on all Spaces" (one-time setup step).
  The display-change hook re-applies the current wallpaper so new displays match.
- Wallpaper folder (assistant's call): flat `~/Pictures/Wallpapers/*.jpg` (+ `.png`/
  `.heic` accepted), same 24 files as Linux, copied manually. `>wallpaper` shows cached
  thumbnails (`~/.cache/celestia/thumbs/`), applies on Return; no live colour preview.
- Notifications: macOS default.
- Bar may change shape/content where SketchyBar requires; it stays a top bar.
- Shortcuts file: `macos/SHORTCUTS.md` (assistant's call on location/format), a table
  of key → action, grouped (windows, spaces, apps, launcher, bar). Covers skhd binds and
  bar mouse actions.

## Left to the builder
- SbarLua file layout under `macos/.config/sketchybar/`; whether to reuse pieces of the
  stray `.config/*.lua` SbarLua files (then delete the strays, which `stow .` would
  otherwise link into `~/.config`) or write fresh.
- Exact pill grouping, sizes, radii, paddings, animation curves; follow Caelestia's
  rounding and Material 3 roles (surface container for pills, primary for active space,
  on-surface text).
- Launcher internals: SwiftPM executable, AppKit `NSPanel` (non-activating, floating,
  `NSVisualEffectView`), how skhd toggles the resident process (e.g. CLI subcommand
  sending a distributed notification / unix socket), fuzzy scoring, icon loading,
  LaunchAgent plist for start at login.
- matugen template contents and the `celestia-wallpaper` implementation (which tool sets
  the desktop picture per display), within the decisions above.
- Which existing shell plugins to port into Lua items vs keep as scripts.
- Install/setup notes (brew packages, fonts, Spotlight shortcut, LaunchAgent, stow) in a
  short section of `macos/SHORTCUTS.md` or a sibling README.
- On-Mac verification checklist per deliverable.
