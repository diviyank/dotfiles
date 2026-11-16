#!/usr/bin/env bash

case "$1" in
    lock)
        hyprlock
        ;;
    exit)
        hyprctl dispatch exit
        ;;
    suspend)
        systemctl suspend
        ;;
    reboot)
        systemctl reboot
        ;;
    shutdown)
        systemctl poweroff
        ;;
    *)
        echo "Usage: $0 {lock|exit|suspend|reboot|shutdown}" >&2
        exit 1
        ;;
esac
