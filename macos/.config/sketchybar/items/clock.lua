local theme = require("theme")
local colors = require("colors")
local icons = require("icons")

local clock = sbar.add("item", "clock", {
  position = "right",
  update_freq = 10,
  icon = { string = icons.calendar_month, color = colors.tertiary },
  label = {
    color = colors.tertiary,
    font = theme.font_string(theme.font.text, "Regular", theme.size.clock),
  },
})

local function update()
  sbar.exec("date '+%a %b %-d %-H:%M'", function(result)
    if type(result) == "string" then
      clock:set({ label = { string = (result:gsub("%s+$", "")) } })
    end
  end)
end

clock:subscribe({ "routine", "forced", "system_woke" }, update)
update()
