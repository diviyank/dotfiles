#!/usr/bin/env zsh

update_space() {
    IDX="${NAME##*.}"                       # current_space.2 -> display 2

    # Ask yabai directly which space is visible on THIS display, rather than
    # trusting the event's $INFO index. When a space moves between displays yabai
    # renumbers indices, and the $INFO index momentarily points at the wrong space
    # -- the bar would flash a random number until the next event. Querying the
    # visible space by display sidesteps that race entirely.
    #
    # The LABEL is the stable identity (cmd+N navigates by label); show its number
    # so the bar matches the keybinds and a moved space keeps its number.
    SPACES=$(/opt/homebrew/bin/yabai -m query --spaces --display "$IDX" 2>/dev/null)
    LABEL=$(echo "$SPACES" | jq -r 'map(select(.["is-visible"]))[0].label // empty')
    SPACE_IDX=$(echo "$SPACES" | jq -r 'map(select(.["is-visible"]))[0].index // empty')
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
