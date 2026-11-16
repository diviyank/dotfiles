#!/usr/bin/env bash

PIDFILE="/tmp/gif-record.pid"
TMPVIDEO="/tmp/gif-record.mp4"
OUTDIR="$HOME/Pictures/GIFs"

if [ -f "$PIDFILE" ]; then
    RECORDER_PID="$(cat "$PIDFILE")"
    rm "$PIDFILE"
    kill -INT "$RECORDER_PID" 2>/dev/null
    while kill -0 "$RECORDER_PID" 2>/dev/null; do sleep 0.1; done
    notify-send "GIF Recording" "Stopped. Converting..."

    mkdir -p "$OUTDIR"
    OUTFILE="$OUTDIR/$(date +%Y%m%d-%H%M%S).gif"
    ffmpeg -i "$TMPVIDEO" -vf "fps=15,scale=iw:-1:flags=lanczos,split[s0][s1];[s0]palettegen[p];[s1][p]paletteuse" -y "$OUTFILE" 2>/dev/null
    rm -f "$TMPVIDEO"

    wl-copy < "$OUTFILE"
    notify-send "GIF Saved" "$OUTFILE (copied to clipboard)"
else
    GEOMETRY="$(slurp)"
    [ -z "$GEOMETRY" ] && exit 1

    wf-recorder -g "$GEOMETRY" -f "$TMPVIDEO" &
    echo $! > "$PIDFILE"
    notify-send "GIF Recording" "Started. Press SUPER+SHIFT+' again to stop."
fi
