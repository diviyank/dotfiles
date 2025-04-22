focus_app() {
  current_workspace=$(/opt/homebrew/bin/aerospace list-workspaces --focused)
  app_window_id=$(/opt/homebrew/bin/aerospace list-windows --all | rg kitty_scratch | awk -F '|' '{print $1}') 
  /opt/homebrew/bin/aerospace move-node-to-workspace --focus-follows-window --window-id $app_window_id $current_workspace
  # /opt/homebrew/bin/aerospace focus --window-id $app_window_id
  # /opt/homebrew/bin/aerospace workspace $current_workspace
  /opt/homebrew/bin/aerospace move-mouse window-lazy-center
}

app_closed() {
  if [ "$(/opt/homebrew/bin/aerospace list-windows --all | rg kitty_scratch | awk -F '|' '{print $1}')" ]; then
    false
  else
    true
  fi
}

app_focused() {
if [ "$(/opt/homebrew/bin/aerospace list-windows --focused | rg kitty_scratch | awk -F '|' '{print $1}')" ]; then
    true
  else
    false
  fi
}

unfocus_app() {
  current_monitor=$(/opt/homebrew/bin/aerospace list-monitors --focused)
  /opt/homebrew/bin/aerospace move-node-to-workspace 0
  /opt/homebrew/bin/aerospace move-workspace-to-monitor $current_monitor
}


if app_closed; then
  open -na /Applications/kitty.app/Contents/MacOS/kitty --args --title kitty_scratch
  sleep 1.5
else
  if app_focused; then
    unfocus_app
  else
    focus_app
  fi
fi
