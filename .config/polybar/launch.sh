#!/usr/bin/env sh

# Terminate already running bar instances
killall -q polybar

# Wait until the processes have been shut down
while pgrep -u $UID -x polybar >/dev/null; do sleep 1; done

# Launch bar1 and bar2
bash scripts/spotify/launchlistener.sh &
for m in $(polybar --list-monitors | cut -d":" -f1); do
    MONITOR=$m polybar --reload top &
    ln -s /tmp/polybar_mqueue.$! /tmp/ipc-top
done

echo "Bars launched..."
