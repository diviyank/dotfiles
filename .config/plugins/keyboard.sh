#!/bin/bash

# this is jank and ugly, I know
LAYOUT="$(defaults read ~/Library/Preferences/com.apple.HIToolbox.plist AppleSelectedInputSources | grep "KeyboardLayout Name" | cut -c 33- | rev | cut -c 2- | rev)"
ICON=
# specify short layouts individually.
case "$LAYOUT" in
    "us-altgr-intl") SHORT_LAYOUT="US";;
    "\"U.S.\"") SHORT_LAYOUT="US";;
    *) SHORT_LAYOUT="FR";;
esac
echo $SHORT_LAYOUT $LAYOUT

sketchybar --set keyboard icon="$ICON" label="$SHORT_LAYOUT"
