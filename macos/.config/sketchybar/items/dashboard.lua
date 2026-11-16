local theme = require("theme")
local colors = require("colors")
local icons = require("icons")
local clock = require("items.clock")
local weather = require("items.weather")
local spotify = require("items.spotify")

local CALENDAR_ROWS = 8
local POPUP = "popup." .. clock.name

local function popup_item(name, props)
  local defaults = {
    position = POPUP,
    padding_left = theme.padding.large,
    padding_right = theme.padding.large,
    background = { drawing = false },
  }
  for key, value in pairs(props) do defaults[key] = value end
  return sbar.add("item", "dashboard." .. name, defaults)
end

clock:set({
  popup = {
    align = "right",
    background = {
      color = colors.surface,
      corner_radius = theme.rounding.extra_large,
      border_width = 0,
    },
  },
})

local date = popup_item("date", {
  icon = { drawing = false },
  label = { font = theme.font_string(theme.font.text, "Medium", theme.size.title_small), color = colors.on_surface },
})

local calendar = {}
for row = 1, CALENDAR_ROWS do
  calendar[row] = popup_item("calendar." .. row, {
    icon = { drawing = false },
    label = {
      font = theme.font_string(theme.font.mono, "Regular", theme.size.mono_small),
      color = colors.on_surface_variant,
    },
  })
end

local weather_row = popup_item("weather", {
  icon = { font = theme.font_string(theme.font.icon, "Regular", theme.icon_size.large), color = colors.primary },
  label = { font = theme.font_string(theme.font.text, "Regular", theme.size.body_medium), color = colors.on_surface },
})

local media = popup_item("media", {
  icon = { string = icons.music_note, color = colors.primary },
  label = { font = theme.font_string(theme.font.text, "Regular", theme.size.body_medium), color = colors.on_surface },
})

local controls = {}
for _, control in ipairs({
  { name = "prev", icon = icons.skip_previous, command = "previous track" },
  { name = "playpause", icon = icons.play_arrow, command = "playpause" },
  { name = "next", icon = icons.skip_next, command = "next track" },
}) do
  controls[control.name] = popup_item(control.name, {
    drawing = false,
    icon = {
      string = control.icon,
      font = theme.font_string(theme.font.icon, "Regular", theme.icon_size.medium),
      color = colors.on_surface,
    },
    label = { drawing = false },
  })
  controls[control.name]:subscribe("mouse.clicked", function() spotify.command(control.command) end)
end

local function contains_day(line, day)
  return line:find("%f[%d]" .. day .. "%f[%D]") ~= nil
end

local function refresh_calendar()
  local today = os.date("*t", os.time()).day
  sbar.exec("cal -h", function(result)
    local lines = {}
    for line in tostring(result):gmatch("([^\n]*)\n") do table.insert(lines, line) end
    for row, entry in ipairs(calendar) do
      local line = (lines[row] or ""):gsub("%s+$", "")
      local is_week = row > 2
      entry:set({
        drawing = line ~= "",
        label = {
          string = line,
          color = (is_week and contains_day(line, today)) and colors.primary or colors.on_surface_variant,
        },
      })
    end
  end)
end

local function refresh_media()
  spotify.state(function(state)
    local active = state.playing or state.paused
    media:set({ label = { string = spotify.describe(state) or "Nothing playing" } })
    for _, control in pairs(controls) do control:set({ drawing = active }) end
    controls.playpause:set({ icon = { string = state.playing and icons.pause or icons.play_arrow } })
  end)
end

media:subscribe("spotify_change", refresh_media)

local function refresh()
  sbar.exec("date '+%A %-d %B'", function(result)
    date:set({ label = { string = (tostring(result):gsub("%s+$", "")) } })
  end)
  refresh_calendar()
  weather.current(function(data)
    if not data then return weather_row:set({ drawing = false }) end
    weather_row:set({
      drawing = true,
      icon = { string = data.icon },
      label = { string = string.format("%s · %s · %s", data.temp, data.desc, data.moon) },
    })
  end)
  refresh_media()
end

clock:subscribe("mouse.clicked", function()
  clock:set({ popup = { drawing = "toggle" } })
  refresh()
end)
clock:subscribe("mouse.exited.global", function()
  clock:set({ popup = { drawing = false } })
end)
