local colors = require("colors")
local icons = require("icons")

local OSASCRIPT = "/usr/bin/osascript"
local LEVELS_QUERY = OSASCRIPT
  .. [[ -e 'set levels to get volume settings']]
  .. [[ -e 'return (output volume of levels as text) & " " & (output muted of levels as text)']]
local TOGGLE_MUTE = OSASCRIPT .. [[ -e 'set volume output muted not (output muted of (get volume settings))']]
local SCROLL_STEP = 2

local volume = sbar.add("item", "volume", {
  position = "right",
  icon = { string = icons.volume_up, color = colors.secondary },
  background = { drawing = false },
})

local function icon_for(level, muted)
  if muted then return icons.volume_off end
  if level >= 50 then return icons.volume_up end
  if level > 0 then return icons.volume_down end
  return icons.volume_mute
end

local function update()
  sbar.exec(LEVELS_QUERY, function(result)
    local level, muted = tostring(result):match("^(%d+) (%a+)")
    level = tonumber(level)
    if not level then return end
    muted = muted == "true"
    volume:set({
      icon = { string = icon_for(level, muted) },
      label = { string = (muted and 0 or level) .. "%" },
    })
  end)
end

volume:subscribe({ "volume_change", "system_woke" }, update)
volume:subscribe("mouse.clicked", function()
  sbar.exec(TOGGLE_MUTE, update)
end)
local function scroll_delta(env)
  local info_delta = type(env.INFO) == "table" and tonumber(env.INFO.delta)
  return tonumber(env.SCROLL_DELTA) or info_delta or 0
end

volume:subscribe("mouse.scrolled", function(env)
  local step = string.format("%+d", math.floor(scroll_delta(env) * SCROLL_STEP + 0.5))
  sbar.exec(OSASCRIPT .. " -e 'set volume output volume ((output volume of (get volume settings)) " .. step .. ")'")
end)
update()
