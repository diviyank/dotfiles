#!/usr/bin/env zsh
# attention.sh
# Show which displays have windows demanding attention (discord/mail/…)
# Requirements: yabai, jq, paste (macOS has paste)


SPACES=$(/opt/homebrew/bin/yabai -m query --windows 2>/dev/null \
  | /usr/bin/jq -r '[.[] | select(."is-demanding-attention"==true) | .space] | unique | sort | join(",")' 2>/dev/null)

if [[ -n "$SPACES" ]]; then
    sketchybar --set "$NAME" drawing=on label="$SPACES"
else
    sketchybar --set "$NAME" drawing=off
fi
