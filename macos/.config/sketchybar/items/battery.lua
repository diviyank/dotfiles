local colors = require("colors")
local icons = require("icons")

local LOW_PERCENT = 20

local battery = sbar.add("item", "battery", {
  position = "right",
  update_freq = 20,
  icon = { string = icons.battery_full, color = colors.secondary },
  background = { drawing = false },
})

local function icon_for(percent, charging)
  if percent >= 100 then
    return charging and icons.battery_charging_full or icons.battery_full
  end
  return icons["battery_" .. math.floor(percent * 7 / 100) .. "_bar"]
end

local function update()
  sbar.exec("/usr/bin/pmset -g batt", function(result)
    local output = tostring(result)
    local percent = tonumber(output:match("(%d+)%%"))
    if not percent then return end
    local charging = output:match(";%s*charging;") ~= nil
    battery:set({
      icon = {
        string = icon_for(percent, charging),
        color = (percent <= LOW_PERCENT and not charging) and colors.error or colors.secondary,
      },
      label = { string = percent .. "%" },
    })
  end)
end

battery:subscribe({ "routine", "forced", "power_source_change", "system_woke" }, update)
update()
