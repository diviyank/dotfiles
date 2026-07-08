#!/usr/bin/env zsh

update_space() {
    IDX="${NAME##*.}"                       # current_space.2 -> 2
    SPACE_ID=$(echo "$INFO" | jq -r --arg k "display-$IDX" '.[$k]')

    case $SPACE_ID in
    1)
        ICON=󰅶
        ICON_PADDING_LEFT=7
        ICON_PADDING_RIGHT=7
        ;;
    *)
        ICON=$SPACE_ID
        ICON_PADDING_LEFT=9
        ICON_PADDING_RIGHT=10
        ;;
    esac

    sketchybar --set $NAME \
        icon=$ICON \
        icon.padding_left=$ICON_PADDING_LEFT \
        icon.padding_right=$ICON_PADDING_RIGHT
}

case "$SENDER" in
"mouse.clicked")
    sketchybar --reload
    ;;
*)
    update_space
    ;;
esac
