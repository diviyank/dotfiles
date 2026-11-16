sbar = require("sketchybar")

local theme = require("theme")
local colors = require("colors")

sbar.begin_config()

sbar.bar({
  position = "top",
  display = "all",
  sticky = true,
  height = theme.bar.height,
  color = 0x00000000,
  margin = 0,
  padding_left = theme.padding.large,
  padding_right = theme.padding.large,
  notch_width = 188,
})

sbar.default({
  padding_left = theme.padding.extra_small,
  padding_right = theme.padding.extra_small,
  background = {
    height = theme.bar.pill,
    corner_radius = theme.rounding.full,
    color = colors.surface_container,
  },
  icon = {
    font = theme.font_string(theme.font.icon, "Regular", theme.icon_size.medium),
    color = colors.on_surface,
    padding_left = theme.padding.medium,
    padding_right = theme.padding.small,
  },
  label = {
    font = theme.font_string(theme.font.text, "Regular", theme.size.body_small),
    color = colors.on_surface,
    padding_left = 0,
    padding_right = theme.padding.medium,
  },
})

require("items")

sbar.end_config()
sbar.event_loop()
