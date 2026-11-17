# macOS rice

A native Swift shell (`celestia-shell`): the Caelestia frame with a left bar, hover popouts and the launcher, coloured from the wallpaper (matugen), on top of yabai and skhd. Shortcuts: [SHORTCUTS.md](SHORTCUTS.md).

## Setup

Run from the repo root, in this order.

```sh
xcode-select --install
brew install jq rust skhd yabai
cargo install matugen --locked --version 2.4.1
brew install --cask font-google-sans-flex font-rubik font-material-symbols font-caskaydia-cove-nerd-font
stow .
mkdir -p ~/.local/bin ~/.local/state ~/.cache
stow --no-folding -t ~ macos
mkdir -p ~/Pictures/Wallpapers   # copy the 24 wallpapers here
```

System Settings:
- Keyboard > Keyboard Shortcuts > Spotlight: disable Cmd+Space.
- Wallpaper: set "Show on all Spaces".
- Privacy & Security > Automation: allow `celestia-shell` and `yabai` to control System Events (prompted on the first wallpaper change), and `celestia-shell` to control Spotify (prompted on the first dashboard open while Spotify runs).
- Privacy & Security > Calendars: allow `celestia-shell` full access (prompted on the first dashboard open).
- Privacy & Security > Accessibility: allow `celestia-shell` (prompted on first launch) so it handles the volume and brightness keys; without it the keys stay stock.

Then:

```sh
sh macos/shell/make-signing-cert.sh   # once: "Celestia Local" code-signing certificate, so permissions survive rebuilds
macos/shell/install.sh           # builds, installs ~/.local/bin/celestia-shell, loads the LaunchAgent
~/.local/bin/celestia-wallpaper ~/Pictures/Wallpapers/<file>
skhd --restart-service
~/.config/wm/apply-yabai.sh
```

Control: `celestia start|stop|restart|status [shell|yabai|skhd]` (all three by default).

Shell log: `/tmp/celestia-shell.log`. Settings: `~/.config/celestia/shell.json` (`border` in pt, default 6; `weather.location`). Generated colours: `~/.local/state/celestia/` (defaults in `macos/.config/celestia/`).

## Tests

```sh
sh macos/tests/wallpaper/test.sh
sh macos/tests/celestia/test.sh
sh macos/tests/templates/test.sh          # needs matugen 2.4.1 and a wallpaper already set
(cd macos/shell && swift test)
~/.config/wm/selftest.sh
```

## On-Mac verification checklist

Authored on Linux and never run on a Mac: tick each item.

Frame and bar
- [x] Frame on every display: 40 pt left bar, 6 pt border, rounded inner corners; windows sit inside it
- [x] Changing `border` in `shell.json` resizes the frame and yabai padding within a second
- [x] Spaces column lists only this display's spaces with app icons; the highlight follows Cmd+N
- [ ] Opening or closing a window updates the icons within a second
- [ ] `move-space-to-display.sh` moves the space between bars; unplugging a display leaves one bar with every space
- [x] Logo, active window title (vertical, clipped) and clock (flips on the minute)
- [ ] Clicking the logo opens the launcher
- [x] Volume icon follows the volume keys; Mail/Discord badges show within 30 s
- [ ] Scrolling on volume changes it; clicking mutes
- [ ] Battery follows plugging and unplugging the charger
- [x] Hover popouts grow from the bar for the title, volume, Wi-Fi, battery and power, without taking focus
- [ ] Volume popout slider drags the volume
- [ ] Lock locks the screen; Restart shows macOS's confirmation (cancel it)
- [x] Idle: about 0 % CPU, footprint ≈ 21 MB
- [x] Bar popouts open instantly, slide out of the bar and glide between items
- [ ] Clicks right of the bar still reach windows while a popout is open

Dashboard
- [x] `codesign -dv ~/.local/bin/celestia-shell` shows `Authority=Celestia Local`
- [ ] Calendar and Spotify grants survive re-running `install.sh`
- [x] Hovering the top centre (notch height) opens it instantly, sliding out of the top edge; leaving closes it
- [ ] The very top still reveals the menu bar
- [ ] alt+u and clicking the clock pin it; Esc, alt+u or a second click close it; hovering never moves focus
- [x] On the built-in display the content sits below the notch
- [ ] The gear opens System Settings
- [x] Performance: `yes > /dev/null` shows at the top at about 100 % with its PID; closed, the shell is back to 0 % CPU
- [x] Calendar shows today's and tomorrow's events
- [ ] An event added in Calendar.app appears without reopening; arrows change month
- [ ] Clicking a day shows its events; clicking an event joins its call (video icon) or opens it in Calendar.app
- [ ] Clicking CPU or RAM in the process table sorts by it; processes appear about 0.5 s after opening
- [x] Weather shows Paris and writes `~/.local/state/celestia/weather.json`
- [ ] Offline, reopening shows the cached weather with its age; changing `weather.location` refetches on the next open
- [ ] Spotify: track, artist, artwork and progress follow playback; controls work; quitting Spotify shows "Nothing playing" and opening the dashboard doesn't relaunch it
- [x] Footprint ≈ 24 MB closed, 27 MB open, 25 MB a minute after closing (before Spotify artwork)

On-screen display
- [ ] Volume and brightness keys show the OSD in the top half of the right border, never macOS's overlay
- [ ] Steps are 1/16; Shift+Option gives 1/64; Option+key opens Sound or Displays settings
- [ ] Mute shows the muted icon; volume up while muted unmutes
- [ ] Brightness never goes below 10 % (keys, drag or scroll)
- [ ] AirPods or Control Centre volume changes show the OSD too
- [ ] It hides 1.5 s after the last change, unless the mouse is on it
- [ ] Hovering the top half of the right edge opens it; the middle of the right edge still reveals the Dock
- [ ] Dragging or scrolling a slider sets the level
- [ ] Without Accessibility, or with the shell stopped, the keys behave as stock macOS
- [ ] Closed, the shell is back to 0 % CPU

Launcher
- [ ] `macos/shell/install.sh` compiles (first real compile of the AppKit code) and `swift test` passes
- [ ] Cmd+Space opens it in under ~100 ms, bottom-centre of the screen under the mouse
- [ ] yabai does not tile it
- [ ] Typing goes to the launcher straight away, without clicking it
- [ ] Esc and focus loss close it
- [ ] Return on an app ends with that app focused; Utilities apps are found
- [ ] `>wallpaper` shows thumbnails and applies the chosen one
- [ ] Activity Monitor shows about 0 % CPU for `celestia-shell` when idle
- [ ] Running `install.sh` twice still leaves a working launcher
- [ ] Errors, if any, appear in `/tmp/celestia-shell.log`

Wallpaper
- [ ] `celestia-wallpaper <file>` sets every display and creates `~/.local/state/celestia/colors.json`
- [ ] The frame and bar recolour live; the launcher on its next open
- [ ] Plugging a display re-applies the wallpaper (display-change hook)
- [ ] System Events Automation is allowed for `celestia-shell` and `yabai`; a wallpaper picked in the launcher applies

Scripts
- [x] Swift, wallpaper and template tests pass; `~/.config/wm/selftest.sh` passes
