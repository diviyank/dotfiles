local theme = require("theme")
local colors = require("colors")

local YABAI = "/opt/homebrew/bin/yabai"
local SKETCHYBAR = "/opt/homebrew/bin/sketchybar"

local label_numbers = {
  one = 1, two = 2, three = 3, four = 4, five = 5, six = 6,
  seven = 7, eight = 8, nine = 9, ten = 10, eleven = 11,
}

-- Spaces are added once yabai answers (asynchronously), after later items;
-- this anchor keeps their slot at the start of the left side.
sbar.add("item", "spaces", { position = "left", drawing = false })

local function visible_space(spaces)
  if type(spaces) ~= "table" then return nil end
  for _, space in ipairs(spaces) do
    if space["is-visible"] then return space end
  end
end

-- The label is the stable identity (cmd+N navigates by label), and the
-- visible space is queried per display rather than trusting $INFO, whose
-- index is stale for a moment when a space moves between displays.
local function update(space_item, display)
  sbar.exec(YABAI .. " -m query --spaces --display " .. display, function(spaces)
    local visible = visible_space(spaces)
    if not visible then return end
    local number = label_numbers[visible.label] or visible.index
    sbar.animate(theme.anim.curve, theme.anim.spatial, function()
      space_item:set({ icon = { string = tostring(number) } })
    end)
  end)
end

local function add_space(display)
  local name = "space." .. display
  local space_item = sbar.add("item", name, {
    position = "left",
    display = display,
    icon = {
      font = theme.font_string(theme.font.numbers, "Medium", theme.size.space_number),
      color = colors.on_primary,
      padding_left = theme.padding.medium,
      padding_right = theme.padding.medium,
    },
    label = { drawing = false },
    background = { color = colors.primary },
  })
  sbar.exec(SKETCHYBAR .. " --move " .. name .. " before spaces")

  space_item:subscribe({ "space_change", "display_change", "system_woke", "mouse.clicked" }, function(env)
    if env.SENDER == "mouse.clicked" then
      sbar.exec(SKETCHYBAR .. " --reload")
    else
      update(space_item, display)
    end
  end)
  update(space_item, display)
end

sbar.exec(YABAI .. " -m query --displays", function(displays)
  if type(displays) ~= "table" then return end
  for _, display in ipairs(displays) do
    add_space(display.index)
  end
end)
