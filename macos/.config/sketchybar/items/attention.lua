local colors = require("colors")
local icons = require("icons")

local YABAI = "/opt/homebrew/bin/yabai"

sbar.add("event", "window_attention_changed")

local attention = sbar.add("item", "attention", {
  position = "left",
  drawing = false,
  update_freq = 10,
  icon = { string = icons.notifications, color = colors.on_error },
  label = { color = colors.on_error },
  background = { color = colors.error },
})

local function demanding_spaces(windows)
  local seen, spaces = {}, {}
  for _, window in ipairs(type(windows) == "table" and windows or {}) do
    if window["is-demanding-attention"] and not seen[window.space] then
      seen[window.space] = true
      table.insert(spaces, window.space)
    end
  end
  table.sort(spaces)
  return spaces
end

local function update()
  sbar.exec(YABAI .. " -m query --windows", function(windows)
    local spaces = demanding_spaces(windows)
    if #spaces == 0 then
      attention:set({ drawing = false })
    else
      attention:set({ drawing = true, label = { string = table.concat(spaces, ",") } })
    end
  end)
end

attention:subscribe({ "window_attention_changed", "routine", "forced" }, update)
update()
