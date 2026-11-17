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
- Privacy & Security > Automation: allow `celestia-shell` and `yabai` to control System Events (prompted on the first wallpaper change); re-check after re-running `install.sh`.

Then:

```sh
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
