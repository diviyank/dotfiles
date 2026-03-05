#!/usr/bin/env zsh

STATE_FILE="$HOME/.config/sketchybar/.pomodoro_state"
FOCUS_DURATION=1200   # 20 min
REST_DURATION=300     # 5 min
CYCLE=$((FOCUS_DURATION + REST_DURATION))

# On click → reset start time to now
if [[ "$SENDER" == "mouse.clicked" ]]; then
    date +%s > "$STATE_FILE"
fi

# Initialize state file if missing
if [[ ! -f "$STATE_FILE" ]]; then
    date +%s > "$STATE_FILE"
fi

START=$(cat "$STATE_FILE")
NOW=$(date +%s)
ELAPSED=$(( (NOW - START) % CYCLE ))

if (( ELAPSED < FOCUS_DURATION )); then
    REMAINING=$(( FOCUS_DURATION - ELAPSED ))
    COLOR=0xffed8796   # red — focus
    ICON="󰔛"
else
    REMAINING=$(( CYCLE - ELAPSED ))
    COLOR=0xffeed49f   # yellow — rest
    ICON="󰒲"
fi
#
# Notify on phase transition (within the first tick of a new phase)
if (( ELAPSED == 0 )) || (( ELAPSED == FOCUS_DURATION )); then
    if (( ELAPSED == FOCUS_DURATION )); then
        osascript -e 'display notification "Time to rest! 5 minutes." with title "Pomodoro"'
    else
        osascript -e 'display notification "Focus time! 20 minutes." with title "Pomodoro"'
    fi
fi

MINS=$(( REMAINING / 60 ))
SECS=$(( REMAINING % 60 ))

sketchybar --set "$NAME" \
    icon="$ICON" \
    label="$(printf '%02d:%02d' $MINS $SECS)" \
    background.color="$BG_COLOR"
