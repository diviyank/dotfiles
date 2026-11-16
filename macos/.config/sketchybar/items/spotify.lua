local colors = require("colors")
local icons = require("icons")

local OSASCRIPT = "/usr/bin/osascript"
local STATE_QUERY = OSASCRIPT
  .. [[ -e 'if application "Spotify" is running then']]
  .. [[ -e 'tell application "Spotify"']]
  .. [[ -e 'try']]
  .. [[ -e 'return (player state as text) & linefeed & (artist of current track) & linefeed & (name of current track)']]
  .. [[ -e 'on error']]
  .. [[ -e 'return player state as text']]
  .. [[ -e 'end try']]
  .. [[ -e 'end tell']]
  .. [[ -e 'end if']]

local click_commands = {
  left = "playpause",
  right = "next track",
  other = "previous track",
}

local spotify = {}

function spotify.state(callback)
  sbar.exec(STATE_QUERY, function(result)
    local lines = {}
    for line in (tostring(result) .. "\n"):gmatch("([^\n]*)\n") do table.insert(lines, line) end
    callback({
      running = (lines[1] or "") ~= "",
      playing = lines[1] == "playing",
      paused = lines[1] == "paused",
      artist = lines[2],
      title = lines[3],
    })
  end)
end

function spotify.describe(state)
  if not state.title or state.title == "" then return nil end
  if (state.artist or "") == "" then return state.title end
  return string.format("%s — %s", state.artist, state.title)
end

function spotify.command(command)
  sbar.exec(OSASCRIPT
    .. [[ -e 'if application "Spotify" is running then']]
    .. [[ -e 'tell application "Spotify" to ]] .. command .. "'"
    .. [[ -e 'end if']])
end

sbar.add("event", "spotify_change", "com.spotify.client.PlaybackStateChanged")

local item = sbar.add("item", "spotify", {
  position = "left",
  drawing = false,
  icon = { string = icons.music_note, color = colors.primary },
  label = { color = colors.primary, max_chars = 35 },
})

local function update()
  spotify.state(function(state)
    local accent = state.playing and colors.primary or colors.outline
    local description = spotify.describe(state)
    item:set({
      drawing = state.playing or state.paused,
      icon = { color = accent },
      label = {
        drawing = description ~= nil,
        string = description or "",
        color = accent,
      },
    })
  end)
end

item:subscribe({ "spotify_change", "system_woke" }, update)
item:subscribe("mouse.clicked", function(env)
  local command = click_commands[env.BUTTON]
  if command then spotify.command(command) end
end)
update()

return spotify
