#!/bin/bash

while true; do
    player_status=$(playerctl -p spotify status 2>/dev/null)
    
    if [ "$player_status" = "Playing" ]; then
        artist=$(playerctl -p spotify metadata artist 2>/dev/null)
        title=$(playerctl -p spotify metadata title 2>/dev/null)
        # Use jq to safely build JSON — handles all special chars
        output=$(jq -cn --arg text " $artist – $title" --arg class "custom-spotify" --arg alt "Playing" \
            '{text: $text, class: $class, alt: $alt}')
        echo "$output"

    elif [ "$player_status" = "Paused" ]; then
        artist=$(playerctl -p spotify metadata artist 2>/dev/null)
        title=$(playerctl -p spotify metadata title 2>/dev/null)
        output=$(jq -cn --arg text " $artist – $title" --arg class "custom-spotify-paused" --arg alt "Paused" \
            '{text: $text, class: $class, alt: $alt}')
        echo "$output"

    else
        # Spotify not running
        echo '{"text": "", "class": "custom-spotify-off", "alt": "Stopped"}'
    fi

    sleep 3
done
