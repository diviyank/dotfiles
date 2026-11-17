# macOS rice

SketchyBar (SbarLua) bar, clock dashboard popup, native Swift launcher and wallpaper-derived colours (matugen), on top of yabai and skhd. Shortcuts: [SHORTCUTS.md](SHORTCUTS.md).

## Setup

Run from the repo root, in this order.

```sh
xcode-select --install
brew install lua jq rust sketchybar skhd yabai
git clone https://github.com/FelixKratz/SbarLua.git /tmp/SbarLua && (cd /tmp/SbarLua && make install) && rm -rf /tmp/SbarLua
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
~/.local/bin/celestia-wallpaper ~/Pictures/Wallpapers/lakes-02-lake-hawea-05.jpg
brew services restart sketchybar
skhd --restart-service
~/.config/wm/apply-yabai.sh
```

Launcher log: `/tmp/celestia-shell.log`. Generated colours: `~/.local/state/celestia/` (defaults in `macos/.config/celestia/`).

## Tests

```sh
lua macos/tests/sketchybar/run.lua        # Lua 5.5, as embedded by SbarLua
sh macos/tests/wallpaper/test.sh
sh macos/tests/templates/test.sh          # needs matugen 2.4.1 and a wallpaper
(cd macos/shell && swift test)
~/.config/wm/selftest.sh
```

## On-Mac verification checklist

Authored on Linux and never run on a Mac: tick each item.

Bar
- [ ] Bar on every display at 40 pt, not under the notch
- [ ] yabai windows do not overlap the bar
- [ ] One space item per display; its number updates on Cmd+N and when a space moves
- [ ] Space numbers stay left of the front app on every display (async ordering via the hidden `spaces` anchor)
- [ ] Fonts render: Google Sans Flex text, Rubik space numbers, Material Symbols Rounded icons, no tofu boxes
- [ ] Status pill height and corner radius look right
- [ ] Battery, weather, pomodoro, mail and Discord items show and update
- [ ] Attention item appears when an app demands attention (yabai field `is-demanding-attention` is unverified; 10 s poll)
- [ ] Spotify not running or not installed: no "Where is Spotify?" dialog and Spotify is not launched
- [ ] Spotify running: item and dashboard media row, including the play/pause glyph, update after its own controls
- [ ] Scrolling on the volume item changes the volume; click mutes
- [ ] Built-in display with Spotify playing and a long app name: nothing under the notch

Dashboard
- [ ] Clicking the clock opens the popup; `cal -h` shows a clean 8-line calendar with today highlighted
- [ ] Weather row shows icon, temperature, condition and moon phase
- [ ] Prev / play-pause / next controls drive Spotify
- [ ] Popup alignment and padding look right
- [ ] Moving the mouse onto the popup keeps it open; leaving closes it

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
- [ ] `celestia-wallpaper <file>` sets every display and creates `~/.local/state/celestia/colors.lua`
- [ ] Bar recolours after the reload and the launcher on its next open
- [ ] Plugging a display re-applies the wallpaper (display-change hook)
- [ ] System Events Automation is allowed for `celestia-shell` and `yabai`; a wallpaper picked in the launcher applies

Scripts
- [ ] Lua, wallpaper and template tests pass; `~/.config/wm/selftest.sh` passes
