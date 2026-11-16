local theme = {
  font = {
    text = "Google Sans Flex",
    numbers = "Rubik",
    icon = "Material Symbols Rounded",
    mono = "CaskaydiaCove Nerd Font Mono",
  },
  size = {
    label_small = 15,
    label_medium = 16,
    body_small = 16,
    body_medium = 19,
    body_large = 21,
    title_small = 19,
    mono_small = 16,
    clock = 18,
    space_number = 18,
  },
  icon_size = { small = 20, medium = 24, large = 32, extra_large = 48 },
  padding = { extra_small = 4, small = 8, medium = 12, large = 16 },
  anim = { curve = "tanh", small = 12, normal = 24, spatial = 30 },
  bar = { height = 40, pill = 32 },
}

theme.rounding = { small = 6, medium = 9, large = 12, extra_large = 21, full = theme.bar.pill // 2 }

function theme.font_string(family, style, size)
  return string.format("%s:%s:%.1f", family, style, size)
end

return theme
