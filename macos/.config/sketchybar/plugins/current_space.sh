#!/usr/bin/env zsh

update_space() {
    IDX="${NAME##*.}"                       # current_space.2 -> 2
    SPACE_IDX=$(echo "$INFO" | jq -r --arg k "display-$IDX" '.[$k]')

    # yabai renumbers space INDICES when a space moves between displays; the LABEL
    # is the stable identity, and cmd+N navigates by label. Show the label's number
    # so the bar matches the keybinds and a moved space keeps its number.
    LABEL=$(/opt/homebrew/bin/yabai -m query --spaces --space "$SPACE_IDX" 2>/dev/null | jq -r '.label // empty')
    case $LABEL in
        one) NUM=1 ;;   two) NUM=2 ;;   three) NUM=3 ;; four) NUM=4 ;;  five) NUM=5 ;;
        six) NUM=6 ;;   seven) NUM=7 ;; eight) NUM=8 ;; nine) NUM=9 ;;  ten) NUM=10 ;;
        eleven) NUM=11 ;;
        *) NUM=$SPACE_IDX ;;                # unlabeled slab -> fall back to its index
    esac

    case $NUM in
    1)
        ICON=󰅶
        ICON_PADDING_LEFT=7
        ICON_PADDING_RIGHT=7
        ;;
    *)
        ICON=$NUM
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
