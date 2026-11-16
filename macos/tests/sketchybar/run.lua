local tests_dir = arg[0]:match("^(.*)/[^/]*$") or "."
local macos_dir = tests_dir .. "/../.."
local config_dir = macos_dir .. "/.config/sketchybar"
local celestia_dir = macos_dir .. "/.config/celestia"

package.path = tests_dir .. "/?.lua;" .. config_dir .. "/?.lua;" .. config_dir .. "/?/init.lua;" .. package.path

local stub = require("stub_sketchybar")
local default_colors = dofile(celestia_dir .. "/default-colors.lua")

local env_overrides = {}
local real_getenv = os.getenv
os.getenv = function(name)
  if env_overrides[name] ~= nil then return env_overrides[name] end
  return real_getenv(name)
end

local tmp_dir = os.tmpname()
os.remove(tmp_dir)
os.execute("mkdir -p '" .. tmp_dir .. "'")

local function write_state(content)
  local file = assert(io.open(tmp_dir .. "/colors.lua", "w"))
  file:write(content)
  file:close()
end

local function displays(count)
  local list = {}
  for index = 1, count do list[index] = { index = index } end
  return list
end

local function load_bar(responses)
  stub.reset()
  stub.responses = responses or { ["query %-%-displays"] = displays(1) }
  env_overrides.CELESTIA_STATE_DIR = env_overrides.CELESTIA_STATE_DIR or tmp_dir .. "/missing"
  env_overrides.CELESTIA_CONFIG_DIR = celestia_dir
  for name in pairs(package.loaded) do
    if name == "init" or name == "theme" or name == "icons" or name == "colors"
      or name == "items" or name:match("^items%.") then
      package.loaded[name] = nil
    end
  end
  package.loaded.sketchybar = stub
  require("init")
  return stub
end

local function eq(actual, expected, what)
  if actual ~= expected then
    error(string.format("%s: expected %s, got %s", what, tostring(expected), tostring(actual)), 2)
  end
end

local function item(name)
  return assert(stub.items[name], "missing item " .. name)
end

local tests = {}

function tests.test_bar_style()
  load_bar()
  local bar = stub.bar_props
  eq(bar.height, 40, "bar.height")
  eq(bar.color, 0x00000000, "bar.color")
  eq(bar.notch_width, 188, "bar.notch_width")
  eq(bar.display, "all", "bar.display")
  eq(bar.sticky, true, "bar.sticky")
  local default = stub.default_props
  eq(default.background.height, 32, "default background.height")
  eq(default.background.corner_radius, 16, "default background.corner_radius")
  eq(default.background.color, default_colors.surface_container, "default background.color")
  eq(default.icon.font, "Material Symbols Rounded:Regular:24.0", "default icon.font")
  eq(default.label.font, "Google Sans Flex:Regular:16.0", "default label.font")
  eq(default.label.color, default_colors.on_surface, "default label.color")
  eq(#stub.find("begin_config"), 1, "begin_config")
  eq(#stub.find("end_config"), 1, "end_config")
  eq(#stub.find("event_loop"), 1, "event_loop")
end

function tests.test_spaces_one_item_per_display()
  load_bar({ ["query %-%-displays"] = displays(1) })
  eq(item("space.1").props.display, 1, "space.1 display")
  eq(stub.items["space.2"], nil, "space.2 with one display")

  load_bar({ ["query %-%-displays"] = displays(3) })
  for index = 1, 3 do
    eq(item("space." .. index).props.display, index, "space." .. index .. " display")
  end
  eq(stub.items["space.4"], nil, "space.4 with three displays")
end

function tests.test_space_label_to_number()
  local spaces = {
    ["query %-%-displays"] = displays(2),
    ["%-%-spaces %-%-display 1$"] = { { index = 6, label = "", ["is-visible"] = false },
                                      { index = 7, label = "", ["is-visible"] = true } },
    ["%-%-spaces %-%-display 2$"] = { { index = 2, label = "two", ["is-visible"] = false },
                                      { index = 3, label = "three", ["is-visible"] = true } },
  }
  load_bar(spaces)
  local space = item("space.2")
  eq(space.props.icon.string, "3", "labelled space number")
  eq(space.props.icon.font, "Rubik:Medium:18.0", "space number font")
  eq(space.props.icon.color, default_colors.on_primary, "space number colour")
  eq(space.props.background.color, default_colors.primary, "space pill colour")
  eq(item("space.1").props.icon.string, "7", "unlabeled space falls back to index")

  spaces["%-%-spaces %-%-display 2$"] = { { index = 3, label = "eleven", ["is-visible"] = true } }
  stub.calls = {}
  stub.fire(space, "space_change")
  eq(space.props.icon.string, "11", "eleven after space_change")
  local animations = stub.find("animate")
  eq(#animations, 1, "space change animations")
  eq(animations[1].args[1], "tanh", "animation curve")
  eq(animations[1].args[2], 30, "animation frames")
  for _, event in ipairs({ "space_change", "display_change", "system_woke", "mouse.clicked" }) do
    assert(space.handlers[event], "space not subscribed to " .. event)
  end
end

function tests.test_front_app()
  load_bar()
  local icons = require("icons")
  local front_app = item("front_app")
  stub.fire(front_app, "front_app_switched", { INFO = "kitty" })
  eq(front_app.props.label.string, "kitty", "front app label")
  eq(front_app.props.label.color, default_colors.primary, "front app label colour")
  eq(front_app.props.label.font, "Google Sans Flex:Regular:16.0", "front app label font")
  eq(front_app.props.icon.color, default_colors.primary, "front app icon colour")
  eq(front_app.props.icon.string, icons.terminal, "kitty icon")
  stub.fire(front_app, "front_app_switched", { INFO = "Slack" })
  eq(front_app.props.icon.string, icons.chat, "Slack icon")
  stub.fire(front_app, "front_app_switched", { INFO = "google chrome" })
  eq(front_app.props.icon.string, icons.web, "case-insensitive app match")
  stub.fire(front_app, "front_app_switched", { INFO = "Some Unknown App" })
  eq(front_app.props.icon.string, icons.desktop_windows, "unknown app icon")
end

function tests.test_clock()
  load_bar({
    ["query %-%-displays"] = displays(1),
    ["^date '%+%%a %%b %%%-d %%%-H:%%M'$"] = "Mon Nov 16 9:41\n",
  })
  local clock = item("clock")
  stub.fire(clock, "routine")
  eq(clock.props.icon.string, utf8.char(0xEBCC), "clock icon")
  eq(clock.props.icon.color, default_colors.tertiary, "clock icon colour")
  eq(clock.props.label.color, default_colors.tertiary, "clock label colour")
  eq(clock.props.label.font, "Google Sans Flex:Regular:18.0", "clock label font")
  eq(clock.props.update_freq, 10, "clock update_freq")
  eq(clock.props.label.string, "Mon Nov 16 9:41", "clock label")
end

function tests.test_colors_fallback()
  local state_dir = tmp_dir .. "/state"
  os.execute("mkdir -p '" .. state_dir .. "'")
  env_overrides.CELESTIA_STATE_DIR = state_dir
  os.remove(state_dir .. "/colors.lua")
  load_bar()
  eq(require("colors").primary, default_colors.primary, "missing state file")

  local file = assert(io.open(state_dir .. "/colors.lua", "w"))
  file:write("syntax error(")
  file:close()
  load_bar()
  eq(require("colors").primary, default_colors.primary, "broken state file")

  file = assert(io.open(state_dir .. "/colors.lua", "w"))
  file:write("return { primary = 0xff123456, surface_container = 0xff654321 }")
  file:close()
  load_bar()
  local colors = require("colors")
  eq(colors.primary, 0xff123456, "valid state file")
  eq(stub.default_props.background.color, 0xff654321, "bar uses state colours")
  eq(colors.alpha(0xff112233, 0.08), 0x14112233, "alpha replaces alpha byte")
  env_overrides.CELESTIA_STATE_DIR = nil
end

function tests.test_space_click_reloads()
  load_bar()
  stub.calls = {}
  stub.fire(item("space.1"), "mouse.clicked")
  local reloads = stub.find("exec", function(cmd) return cmd:find("sketchybar %-%-reload$") ~= nil end)
  eq(#reloads, 1, "reload on click")
end

local names = {}
for name in pairs(tests) do table.insert(names, name) end
table.sort(names)

local failures = 0
for _, name in ipairs(names) do
  local ok, err = pcall(tests[name])
  if ok then
    print("ok   " .. name)
  else
    failures = failures + 1
    print("FAIL " .. name .. ": " .. tostring(err))
  end
end
os.execute("rm -rf '" .. tmp_dir .. "'")
os.exit(failures == 0 and 0 or 1)
