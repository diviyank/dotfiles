local home = os.getenv("HOME") or ""
local state_dir = os.getenv("CELESTIA_STATE_DIR") or home .. "/.local/state/celestia"
local config_dir = os.getenv("CELESTIA_CONFIG_DIR") or home .. "/.config/celestia"

local function load_palette(path)
  local ok, palette = pcall(dofile, path)
  if ok and type(palette) == "table" then return palette end
end

local colors = load_palette(state_dir .. "/colors.lua")
  or load_palette(config_dir .. "/default-colors.lua")
  or {}

function colors.alpha(color, a)
  return (color & 0x00ffffff) | (math.floor(a * 255 + 0.5) << 24)
end

return colors
