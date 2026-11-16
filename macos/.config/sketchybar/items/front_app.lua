local theme = require("theme")
local colors = require("colors")
local icons = require("icons")

local app_icons = {
  kitty = "terminal", terminal = "terminal", iterm2 = "terminal",
  safari = "web", ["google chrome"] = "web", firefox = "web", arc = "web",
  code = "code", cursor = "code", ["intellij idea"] = "code", pycharm = "code", xcode = "code",
  slack = "chat", discord = "chat", ["microsoft teams"] = "chat", whatsapp = "chat", messages = "chat",
  mail = "mail", outlook = "mail",
  spotify = "music_note", music = "music_note",
  finder = "folder",
  ["system settings"] = "settings",
}

local function icon_for(app)
  return icons[app_icons[(app or ""):lower()] or "desktop_windows"]
end

local front_app = sbar.add("item", "front_app", {
  position = "left",
  icon = { string = icons.desktop_windows, color = colors.primary },
  label = {
    color = colors.primary,
    font = theme.font_string(theme.font.text, "Regular", theme.size.body_small),
  },
})

front_app:subscribe("front_app_switched", function(env)
  front_app:set({ icon = { string = icon_for(env.INFO) }, label = { string = env.INFO } })
end)
