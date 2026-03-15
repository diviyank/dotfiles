#!/usr/bin/env zsh

STATE_FILE="$HOME/.config/waybar/.pomodoro_state"
FOCUS_DURATION=1200
REST_DURATION=300

# Initialize if missing
if [[ ! -f "$STATE_FILE" ]]; then
    echo "$(date +%s) focus" > "$STATE_FILE"
fi

read START PHASE < "$STATE_FILE"
NOW=$(date +%s)
ELAPSED=$(( NOW - START ))

# Called with "toggle" arg from on-click
if [[ "$1" == "toggle" ]]; then
    [[ "$PHASE" == "focus" ]] && PHASE="rest" || PHASE="focus"
    echo "$(date +%s) $PHASE" > "$STATE_FILE"
    exit 0
fi

# Auto-switch when duration expires
if [[ "$PHASE" == "focus" ]] && (( ELAPSED >= FOCUS_DURATION )); then
    PHASE="rest"
    echo "$(date +%s) $PHASE" > "$STATE_FILE"
    ELAPSED=0
    notify-send "Pomodoro" "Time to rest! 5 minutes."
elif [[ "$PHASE" == "rest" ]] && (( ELAPSED >= REST_DURATION )); then
    PHASE="focus"
    echo "$(date +%s) $PHASE" > "$STATE_FILE"
    ELAPSED=0
    notify-send "Pomodoro" "Focus time! 20 minutes."
fi

if [[ "$PHASE" == "focus" ]]; then
    REMAINING=$(( FOCUS_DURATION - ELAPSED ))
    ICON="󰔛"
    if (( ELAPSED < 5 )); then
        echo "{\"text\": \"$ICON  START TO FOCUS\", \"class\": \"splash\", \"tooltip\": \"Click to switch phase\"}"
        exit 0
    fi
    CLASS="focus"
else
    REMAINING=$(( REST_DURATION - ELAPSED ))
    ICON="󰒲"
    CLASS="rest"
fi

MINS=$(( REMAINING / 60 ))
SECS=$(( REMAINING % 60 ))
LABEL="$(printf '%02d:%02d' $MINS $SECS)"

echo "{\"text\": \"$ICON  $LABEL\", \"class\": \"$CLASS\", \"tooltip\": \"Click to switch phase\"}"
