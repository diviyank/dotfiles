#!/usr/bin/env zsh

# 1. Handle Mouse Events
if [ "$SENDER" = "mouse.clicked" ]; then
    osascript -e 'set volume output muted not (output muted of (get volume settings))'
elif [ "$SENDER" = "mouse.scrolled" ]; then
    SCROLL=$(printf "%+d" $(( SCROLL_DELTA * 2 )))
    osascript -e "set volume output volume ((output volume of (get volume settings)) ${SCROLL})"
else 
  VOLUME=${INFO}
  # VOLUME=$(osascript -e 'output volume of (get volume settings)')
  MUTED=$(osascript -e 'output muted of (get volume settings)')

  # 3. Set Icons
  if [ "$MUTED" = "true" ]; then
      ICON=""
      ICON_PADDING_RIGHT=20
      VOLUME=0
  elif [ "$VOLUME" -lt 33 ]; then
      ICON=""
      ICON_PADDING_RIGHT=12
  else
      ICON=""
      ICON_PADDING_RIGHT=6
  fi
  echo $NAME $ICON "$VOLUME%"
  sketchybar --set "$NAME" icon="$ICON" icon.padding_right="$ICON_PADDING_RIGHT" label="$VOLUME%"
fi

# 2. Get current status (Always fetch fresh data)
