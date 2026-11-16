#!/usr/bin/env bash
# Reload the Hyprland session: config + desktop shell components.
# Regular applications are left untouched.

set -u

restart() {
    local name=$1
    shift
    pkill -x "$name" 2>/dev/null
    sleep 0.2
    setsid "$@" >/dev/null 2>&1 &
}

hyprctl reload

restart waybar waybar
restart hyprpaper hyprpaper
restart hypridle hypridle
restart pypr /home/diviyan/.local/bin/pypr
restart nm-applet nm-applet --indicator

sleep 2
for monitor in DP-1 HDMI-A-1; do
    hyprctl hyprpaper wallpaper "$monitor,/home/diviyan/Pictures/nord_dark_city.png"
done

notify-send "Hyprland" "Session reloaded" 2>/dev/null
