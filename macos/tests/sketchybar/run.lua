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

local now_override
local real_time = os.time
os.time = function(date)
  if date == nil and now_override then return now_override end
  return real_time(date)
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
  stub.responses = responses or { { "query %-%-displays", displays(1) } }
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
  load_bar({ { "query %-%-displays", displays(1) } })
  eq(item("space.1").props.display, 1, "space.1 display")
  eq(stub.items["space.2"], nil, "space.2 with one display")

  load_bar({ { "query %-%-displays", displays(3) } })
  for index = 1, 3 do
    eq(item("space." .. index).props.display, index, "space." .. index .. " display")
  end
  eq(stub.items["space.4"], nil, "space.4 with three displays")
end

function tests.test_space_label_to_number()
  local display_2 = { "%-%-spaces %-%-display 2$",
                      { { index = 2, label = "two", ["is-visible"] = false },
                        { index = 3, label = "three", ["is-visible"] = true } } }
  load_bar({
    { "query %-%-displays", displays(2) },
    { "%-%-spaces %-%-display 1$", { { index = 6, label = "", ["is-visible"] = false },
                                     { index = 7, label = "", ["is-visible"] = true } } },
    display_2,
  })
  local space = item("space.2")
  eq(space.props.icon.string, "3", "labelled space number")
  eq(space.props.icon.font, "Rubik:Medium:18.0", "space number font")
  eq(space.props.icon.color, default_colors.on_primary, "space number colour")
  eq(space.props.background.color, default_colors.primary, "space pill colour")
  eq(item("space.1").props.icon.string, "7", "unlabeled space falls back to index")

  display_2[2] = { { index = 3, label = "eleven", ["is-visible"] = true } }
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
    { "query %-%-displays", displays(1) },
    { "^date '%+%%a %%b %%%-d %%%-H:%%M'$", "Mon Nov 16 9:41\n" },
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

local function execs(pattern)
  return stub.find("exec", function(cmd) return cmd:find(pattern) ~= nil end)
end

local function read_file(path)
  local file = io.open(path)
  if not file then return nil end
  local content = file:read("a")
  file:close()
  return content
end

function tests.test_layout()
  load_bar()
  local left, right = {}, {}
  for _, call in ipairs(stub.find("add", function(kind) return kind == "item" end)) do
    local name, props = call.args[2], call.args[3]
    if not name:match("^space%.") then
      table.insert(props.position == "right" and right or left, name)
    end
  end
  eq(table.concat(left, " "), "spaces front_app spotify attention", "left order")
  eq(table.concat(right, " "), "clock battery volume mail discord pomodoro weather", "right order from the edge")
  local status = item("status")
  eq(status.kind, "bracket", "status kind")
  eq(table.concat(status.members, " "), "battery volume mail discord pomodoro", "status members")
  eq(status.props.background.color, default_colors.surface_container, "status pill colour")
  for _, name in ipairs(status.members) do
    eq(item(name).props.icon.color, default_colors.secondary, name .. " icon colour")
    eq(item(name).props.background.drawing, false, name .. " own pill hidden inside bracket")
  end
end

function tests.test_spotify_not_running_hides()
  load_bar({ { "player state", "" } })
  local spotify = item("spotify")
  eq(spotify.props.drawing, false, "spotify hidden")
  local queries = execs('application "Spotify" is running')
  assert(#queries >= 1, "state query guarded by is running")
  assert(spotify.handlers.spotify_change, "spotify subscribes spotify_change")
  local events = stub.find("add", function(kind, name) return kind == "event" and name == "spotify_change" end)
  eq(events[1].args[3], "com.spotify.client.PlaybackStateChanged", "spotify_change notification")
  local state
  require("items.spotify").state(function(result) state = result end)
  eq(state.running, false, "state running")
  eq(state.playing, false, "state playing")
end

function tests.test_spotify_playing()
  local output = "playing\nDaft Punk\nOne More Time\n"
  load_bar({ { "player state", function() return output end } })
  local icons = require("icons")
  local spotify = item("spotify")
  eq(spotify.props.drawing, true, "spotify shown")
  eq(spotify.props.label.string, "Daft Punk — One More Time", "spotify label")
  eq(spotify.props.icon.string, icons.music_note, "spotify icon")
  eq(spotify.props.icon.color, default_colors.primary, "spotify icon colour")
  eq(spotify.props.label.color, default_colors.primary, "spotify label colour")
  local state
  require("items.spotify").state(function(result) state = result end)
  eq(state.running, true, "state running")
  eq(state.playing, true, "state playing")
  eq(state.artist, "Daft Punk", "state artist")
  eq(state.title, "One More Time", "state title")

  stub.calls = {}
  stub.fire(spotify, "mouse.clicked", { BUTTON = "left" })
  eq(#execs('tell application "Spotify" to playpause'), 1, "left click playpause")
  stub.fire(spotify, "mouse.clicked", { BUTTON = "right" })
  eq(#execs('tell application "Spotify" to next track'), 1, "right click next")
  stub.fire(spotify, "mouse.clicked", { BUTTON = "other" })
  eq(#execs('tell application "Spotify" to previous track'), 1, "other click previous")

  output = "paused\nDaft Punk\nOne More Time\n"
  stub.fire(spotify, "spotify_change")
  eq(spotify.props.drawing, true, "paused stays shown")
  eq(spotify.props.icon.color, default_colors.outline, "paused icon colour")

  output = "stopped\n"
  stub.fire(spotify, "spotify_change")
  eq(spotify.props.drawing, false, "stopped hides")
end

function tests.test_battery_levels()
  local pmset
  load_bar({ { "pmset %-g batt", function() return pmset end } })
  local icons = require("icons")
  local battery = item("battery")
  eq(battery.props.update_freq, 20, "battery update_freq")
  local function check(output, icon, color, label, what)
    pmset = output
    stub.fire(battery, "routine")
    eq(battery.props.icon.string, icon, what .. " icon")
    eq(battery.props.icon.color, color, what .. " colour")
    eq(battery.props.label.string, label, what .. " label")
  end
  local ac = "Now drawing from 'AC Power'\n -InternalBattery-0 (id=1)\t"
  local bat = "Now drawing from 'Battery Power'\n -InternalBattery-0 (id=1)\t"
  check(ac .. "100%; charged; 0:00 remaining present: true\n", icons.battery_full, default_colors.secondary, "100%", "full on AC")
  check(ac .. "100%; charging; 0:01 remaining present: true\n", icons.battery_charging_full, default_colors.secondary, "100%", "full charging")
  check(bat .. "50%; discharging; 3:00 remaining present: true\n", icons.battery_3_bar, default_colors.secondary, "50%", "half")
  check(bat .. "15%; discharging; 0:40 remaining present: true\n", icons.battery_1_bar, default_colors.error, "15%", "low discharging")
  check(ac .. "15%; charging; 1:40 remaining present: true\n", icons.battery_1_bar, default_colors.secondary, "15%", "low charging")
  check(bat .. "99%; discharging; 9:00 remaining present: true\n", icons.battery_6_bar, default_colors.secondary, "99%", "99")
  pmset = ""
  stub.fire(battery, "routine")
  eq(battery.props.label.string, "99%", "no battery keeps last value")
end

function tests.test_volume_icons()
  local settings
  load_bar({ { "^/usr/bin/osascript %-e 'set levels to", function() return settings end } })
  local icons = require("icons")
  local volume = item("volume")
  local function check(output, icon, label, what)
    settings = output
    stub.fire(volume, "volume_change", { INFO = "0" })
    eq(volume.props.icon.string, icon, what .. " icon")
    eq(volume.props.label.string, label, what .. " label")
  end
  check("60 true\n", icons.volume_off, "0%", "muted")
  check("60 false\n", icons.volume_up, "60%", "60")
  check("50 false\n", icons.volume_up, "50%", "50")
  check("20 false\n", icons.volume_down, "20%", "20")
  check("0 false\n", icons.volume_mute, "0%", "0")

  stub.calls = {}
  stub.fire(volume, "mouse.clicked")
  eq(#execs("set volume output muted not %(output muted of %(get volume settings%)%)"), 1, "click toggles mute")
  stub.fire(volume, "mouse.scrolled", { SCROLL_DELTA = "3" })
  eq(#execs("set volume output volume %(%(output volume of %(get volume settings%)%) %+6%)"), 1, "scroll up")
  stub.fire(volume, "mouse.scrolled", { SCROLL_DELTA = "-2" })
  eq(#execs("set volume output volume %(%(output volume of %(get volume settings%)%) %-4%)"), 1, "scroll down")
  stub.fire(volume, "mouse.scrolled", { INFO = { delta = 1.5 } })
  eq(#execs("set volume output volume %(%(output volume of %(get volume settings%)%) %+3%)"), 1, "scroll via INFO.delta")
end

local function wttr(code, observed)
  return {
    current_condition = { {
      weatherCode = tostring(code),
      temp_C = "14",
      weatherDesc = { { value = "Sunny" } },
      localObsDateTime = "2026-11-16 " .. observed,
    } },
    weather = { { astronomy = { { sunrise = "07:45 AM", sunset = "05:30 PM", moon_phase = "Waxing Gibbous" } } } },
  }
end

function tests.test_weather_codes()
  local current = wttr(113, "02:00 PM")
  load_bar({
    { "ipinfo%.io", { city = "Saint-Rémy", region = "Île de France" } },
    { "wttr%.in", function() return current end },
  })
  local icons = require("icons")
  local weather = item("weather")
  eq(weather.props.update_freq, 1800, "weather update_freq")
  assert(weather.handlers.system_woke, "weather subscribes system_woke")
  eq(weather.props.icon.string, icons.clear_day, "113 day")
  eq(weather.props.label.string, "14°C", "weather label")
  local url = execs("wttr%.in")[1].args[1]
  assert(url:find("wttr.in/Saint-R%C3%A9my+%C3%8Ele+de+France?format=j1", 1, true), "escaped url: " .. url)

  local function check(code, observed, icon, what)
    current = wttr(code, observed)
    stub.fire(weather, "routine")
    eq(weather.props.icon.string, icon, what)
  end
  check(113, "11:00 PM", icons.bedtime, "113 night")
  check(113, "06:00 AM", icons.bedtime, "113 before sunrise")
  check(116, "11:00 PM", icons.partly_cloudy_night, "116 night")
  check(116, "12:30 PM", icons.partly_cloudy_day, "116 day")
  check(302, "02:00 PM", icons.rainy, "302")
  check(338, "02:00 PM", icons.snowing_heavy, "338")
  check(248, "02:00 PM", icons.foggy, "248")
  check(389, "02:00 PM", icons.thunderstorm, "389")
  check(326, "02:00 PM", icons.cloudy_snowing, "326")
  check(999, "02:00 PM", icons.cloud, "unknown")

  check(302, "02:00 PM", icons.rainy, "before failure")
  current = ""
  stub.fire(weather, "routine")
  eq(weather.props.icon.string, icons.rainy, "failure keeps icon")
  eq(weather.props.label.string, "14°C", "failure keeps label")
  eq(stub.items["weather.moon"], nil, "moon item dropped")

  local data = "unset"
  require("items.weather").current(function(result) data = result end)
  eq(data, nil, "current on failure")
  current = wttr(113, "02:00 PM")
  require("items.weather").current(function(result) data = result end)
  eq(data.icon, icons.clear_day, "current icon")
  eq(data.temp, "14°C", "current temp")
  eq(data.desc, "Sunny", "current desc")
  eq(data.location, "Saint-Rémy", "current location")
  eq(data.moon, "Waxing Gibbous", "current moon")
end

function tests.test_mail_discord_counts()
  local labels = { Mail = "", Discord = "" }
  load_bar({
    { 'StatusLabel "Mail"', function() return '"StatusLabel"={ "label"="' .. labels.Mail .. '" }\n' end },
    { 'StatusLabel "Discord"', function() return '"StatusLabel"={ "label"="' .. labels.Discord .. '" }\n' end },
  })
  local icons = require("icons")
  for app, spec in pairs({ Mail = { "mail", icons.mail, 180, "seven" },
                           Discord = { "discord", icons.forum, 60, "six" } }) do
    local name, icon, freq, space = table.unpack(spec)
    local counter = item(name)
    eq(counter.props.update_freq, freq, name .. " update_freq")
    eq(counter.props.icon.string, icon, name .. " icon")
    eq(counter.props.drawing, false, name .. " hidden at 0")
    labels[app] = "3"
    stub.fire(counter, "routine")
    eq(counter.props.drawing, true, name .. " shown")
    eq(counter.props.label.string, "3", name .. " label")
    labels[app] = ""
    stub.fire(counter, "system_woke")
    eq(counter.props.drawing, false, name .. " hidden again")
    stub.calls = {}
    stub.fire(counter, "mouse.clicked")
    eq(#execs("^/opt/homebrew/bin/yabai %-m space %-%-focus " .. space .. "$"), 1, name .. " click focuses " .. space)
  end
end

function tests.test_pomodoro_state()
  local home = tmp_dir .. "/home"
  local state_file = home .. "/.config/sketchybar/.pomodoro_state"
  os.execute("mkdir -p '" .. home .. "/.config/sketchybar'")
  os.remove(state_file)
  env_overrides.HOME = home
  now_override = 1000
  load_bar()
  local icons = require("icons")
  local pomodoro = item("pomodoro")
  eq(pomodoro.props.update_freq, 1, "pomodoro update_freq")
  eq(read_file(state_file), "1000 focus\n", "state initialised")
  eq(pomodoro.props.icon.string, icons.timer, "focus icon")
  eq(pomodoro.props.label.string, "START TO FOCUS", "focus start label")

  now_override = 1060
  stub.fire(pomodoro, "routine")
  eq(pomodoro.props.label.string, "19:00", "focus countdown")

  stub.calls = {}
  now_override = 2200
  stub.fire(pomodoro, "routine")
  eq(read_file(state_file), "2200 rest\n", "auto switch to rest")
  eq(pomodoro.props.icon.string, icons.coffee, "rest icon")
  eq(pomodoro.props.label.string, "05:00", "rest countdown")
  eq(#execs("display notification \"Time to rest! 5 minutes.\" with title \"Pomodoro\""), 1, "rest notification")

  now_override = 2500
  stub.fire(pomodoro, "routine")
  eq(read_file(state_file), "2500 focus\n", "auto switch to focus")
  eq(#execs("display notification \"Focus time! 20 minutes.\" with title \"Pomodoro\""), 1, "focus notification")

  now_override = 2600
  stub.fire(pomodoro, "mouse.clicked")
  eq(read_file(state_file), "2600 rest\n", "click toggles phase")
  eq(pomodoro.props.icon.string, icons.coffee, "clicked to rest")
  eq(pomodoro.props.label.string, "05:00", "clicked rest countdown")
end

function tests.test_attention()
  local windows = {
    { space = 3, ["is-demanding-attention"] = true },
    { space = 1, ["is-demanding-attention"] = true },
    { space = 3, ["is-demanding-attention"] = true },
    { space = 2, ["is-demanding-attention"] = false },
  }
  load_bar({ { "^/opt/homebrew/bin/yabai %-m query %-%-windows$", function() return windows end } })
  local icons = require("icons")
  local attention = item("attention")
  eq(attention.props.update_freq, 10, "attention update_freq")
  eq(#stub.find("add", function(kind, name) return kind == "event" and name == "window_attention_changed" end), 1,
    "window_attention_changed declared")
  stub.fire(attention, "window_attention_changed")
  eq(attention.props.drawing, true, "attention shown")
  eq(attention.props.label.string, "1,3", "attention spaces")
  eq(attention.props.background.color, default_colors.error, "attention background")
  eq(attention.props.icon.string, icons.notifications, "attention icon")
  eq(attention.props.icon.color, default_colors.on_error, "attention icon colour")
  eq(attention.props.label.color, default_colors.on_error, "attention label colour")
  windows = { { space = 2, ["is-demanding-attention"] = false } }
  stub.fire(attention, "window_attention_changed")
  eq(attention.props.drawing, false, "attention hidden")
end

local names = {}
for name in pairs(tests) do table.insert(names, name) end
table.sort(names)

local failures = 0
for _, name in ipairs(names) do
  for key in pairs(env_overrides) do env_overrides[key] = nil end
  now_override = nil
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
