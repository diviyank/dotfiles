# Shortcuts

Update this file with every bind change (`.skhdrc`, launcher, bar items).

Digit keys are bound by keycode so they work on AZERTY and QWERTY: the keys of the number row, left to right, are spaces 1 to 10.

## Windows

| Keys | Action |
|---|---|
| `cmd - arrows` | Focus window in that direction, falling through to the adjacent display |
| `cmd + shift - arrows` | Move window in that direction, crossing to the adjacent display at the edge |
| `ctrl - f` | Toggle zoom-fullscreen |
| `ctrl + shift - space` | Toggle the space layout between bsp and stack |
| `ctrl + alt + cmd - r` | Reload yabai |

## Spaces

| Keys | Action |
|---|---|
| `cmd - 1..0` (0x12 0x13 0x14 0x15 0x17 0x16 0x1A 0x1C 0x19 0x1D) | Focus space one to ten |
| `cmd + shift - 1..0` (same keycodes) | Move window to space one to ten |
| `cmd + ctrl + shift - arrows` | Move the whole space to the adjacent display and follow it |

## Apps

| Keys | Action |
|---|---|
| `cmd - return` | New kitty window |
| `cmd - tab` | Toggle kitty scratchpad |

## Launcher

| Keys | Action |
|---|---|
| `cmd - space` | Toggle the launcher (Spotlight's Cmd+Space must be disabled) |
| `Return` | Open the selected app, apply the selected wallpaper, or complete the selected command |
| `Esc` | Close |
| `Up` / `Down` | Move selection |
| `Shift+Tab` / `Tab` | Move selection up / down |
| `Left` / `Right` | Move selection in wallpaper mode |
| `>wallpaper` | Wallpaper picker with thumbnails |

## Bar

| Mouse | Action |
|---|---|
| Click a space | Focus that space |
| Click the logo | Open the launcher |
| Click volume | Toggle mute |
| Scroll volume | Change volume by 5 % |
| Click Mail | Focus space seven |
| Click Discord | Focus space six |
| Hover the title, volume, Wi-Fi, battery or power | Open its popout (stays open while the mouse is on it) |
| Power popout | Lock, sleep, restart or shut down |

## Dashboard

| Key or mouse | Action |
|---|---|
| `alt + u` | Toggle the dashboard on the display under the mouse (pinned) |
| Hover the top border, centre | Open it while the mouse stays on it |
| Click the clock | Toggle it pinned |
| `Esc` | Close a pinned dashboard |
| Gear | Open System Settings |
| Calendar arrows / month name | Previous or next month / back to today |
| Click a day | Show that day's events; click it again or today to go back |
| Click an event | Join its Meet, Zoom or Teams call, or open it in Calendar.app |
| Click the CPU or RAM header | Sort the processes by it |

## Terminal

| Command | Action |
|---|---|
| `celestia status` | Show whether the shell, yabai and skhd are running |
| `celestia restart` | Restart all three (or name one: `shell`, `yabai`, `skhd`) |
| `celestia stop` / `celestia start` | Stop or start them |
| `celestia-shell dashboard` | Toggle the dashboard |
