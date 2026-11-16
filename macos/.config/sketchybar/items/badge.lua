local colors = require("colors")

local YABAI = "/opt/homebrew/bin/yabai"

return function(name, app, icon, update_freq, space)
  local badge = sbar.add("item", name, {
    position = "right",
    drawing = false,
    updates = true,
    update_freq = update_freq,
    icon = { string = icon, color = colors.secondary },
    background = { drawing = false },
  })

  local function update()
    sbar.exec('/usr/bin/lsappinfo info -only StatusLabel "' .. app .. '"', function(result)
      local count = tostring(result):match('"label"="([^"]*)"') or ""
      badge:set({ drawing = count ~= "", label = { string = count } })
    end)
  end

  badge:subscribe({ "routine", "forced", "system_woke" }, update)
  badge:subscribe("mouse.clicked", function()
    sbar.exec(YABAI .. " -m space --focus " .. space)
  end)
  update()
end
