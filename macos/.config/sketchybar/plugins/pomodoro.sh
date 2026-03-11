#!/usr/bin/env zsh

STATE_FILE="$HOME/.config/sketchybar/.pomodoro_state"
FOCUS_DURATION=1200
REST_DURATION=300

# Initialize if missing
if [[ ! -f "$STATE_FILE" ]]; then
    echo "$(date +%s) focus" > "$STATE_FILE"
fi

read START PHASE < "$STATE_FILE"
NOW=$(date +%s)
ELAPSED=$(( NOW - START ))

# Click → toggle phase immediately
if [[ "$SENDER" == "mouse.clicked" ]]; then
    [[ "$PHASE" == "focus" ]] && PHASE="rest" || PHASE="focus"
    echo "$(date +%s) $PHASE" > "$STATE_FILE"
    ELAPSED=0
fi

# Auto-switch when duration expires
if [[ "$PHASE" == "focus" ]] && (( ELAPSED >= FOCUS_DURATION )); then
    PHASE="rest"
    echo "$(date +%s) $PHASE" > "$STATE_FILE"
    ELAPSED=0
    osascript -e 'display notification "Time to rest! 5 minutes." with title "Pomodoro"'
elif [[ "$PHASE" == "rest" ]] && (( ELAPSED >= REST_DURATION )); then
    PHASE="focus"
    echo "$(date +%s) $PHASE" > "$STATE_FILE"
    ELAPSED=0
    osascript -e 'display notification "Focus time! 20 minutes." with title "Pomodoro"'
fi

if [[ "$PHASE" == "focus" ]]; then
    REMAINING=$(( FOCUS_DURATION - ELAPSED ))
    ICON="󰔛"
    if (( ELAPSED < 5 )); then
        sketchybar --set "$NAME" \
            icon="$ICON" \
            icon.color=0xff24273a \
            label="START TO FOCUS" \
            label.color=0xff24273a \
            background.color=0xffed8796
        exit 0
    fi
    COLOR=0xffed8796
else
    REMAINING=$(( REST_DURATION - ELAPSED ))
    ICON="󰒲"
    COLOR=0xffeed49f
fi

MINS=$(( REMAINING / 60 ))
SECS=$(( REMAINING % 60 ))

sketchybar --set "$NAME" \
    icon="$ICON" \
    icon.color="$COLOR" \
    label="$(printf '%02d:%02d' $MINS $SECS)" \
    label.color="$COLOR" \
    background.color=0xCC494d64
