local colors = require("colors")
local icons = require("icons")

local phases = {
  focus = { duration = 1200, icon = icons.timer, next = "rest",
            notice = "Focus time! 20 minutes." },
  rest = { duration = 300, icon = icons.coffee, next = "focus",
           notice = "Time to rest! 5 minutes." },
}
local START_LABEL_SECONDS = 5

local pomodoro = sbar.add("item", "pomodoro", {
  position = "right",
  update_freq = 1,
  icon = { string = icons.timer, color = colors.secondary },
  background = { drawing = false },
})

local function state_file()
  return (os.getenv("HOME") or "") .. "/.config/sketchybar/.pomodoro_state"
end

local function write_state(start, phase)
  local file = io.open(state_file(), "w")
  if file then
    file:write(start, " ", phase, "\n")
    file:close()
  end
end

local function read_state()
  local file = io.open(state_file())
  local content = file and file:read("a") or ""
  if file then file:close() end
  local start, phase = content:match("^(%d+) (%a+)")
  if not phases[phase] then return nil end
  return tonumber(start), phase
end

local function begin(phase, now)
  write_state(now, phase)
  return now, phase
end

local function update(env)
  local now = os.time()
  local start, phase = read_state()
  if not start then start, phase = begin("focus", now) end

  if env and env.SENDER == "mouse.clicked" then
    start, phase = begin(phases[phase].next, now)
  elseif now - start >= phases[phase].duration then
    start, phase = begin(phases[phase].next, now)
    sbar.exec(string.format(
      [[/usr/bin/osascript -e 'display notification "%s" with title "Pomodoro"']], phases[phase].notice))
  end

  local elapsed = now - start
  local remaining = phases[phase].duration - elapsed
  local label = string.format("%02d:%02d", remaining // 60, remaining % 60)
  if phase == "focus" and elapsed < START_LABEL_SECONDS then label = "START TO FOCUS" end
  pomodoro:set({ icon = { string = phases[phase].icon }, label = { string = label } })
end

pomodoro:subscribe({ "routine", "forced", "mouse.clicked" }, update)
update()
