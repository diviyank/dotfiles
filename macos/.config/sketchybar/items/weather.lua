local colors = require("colors")
local icons = require("icons")

local CURL = "/usr/bin/curl -s"

local icon_codes = {
  cloud = { 119, 122 },
  foggy = { 143, 248, 260 },
  rainy = { 176, 263, 266, 281, 284, { 293, 314 }, { 353, 359 } },
  cloudy_snowing = { 179, 182, 185, 227, 317, 320, { 323, 332 }, 350, { 362, 368 }, 374, 377 },
  snowing_heavy = { 230, 335, 338, 371, 395 },
  thunderstorm = { 200, 386, 389, 392 },
}

local icon_by_code = {}
for icon, codes in pairs(icon_codes) do
  for _, code in ipairs(codes) do
    local first, last = code, code
    if type(code) == "table" then first, last = code[1], code[2] end
    for each = first, last do icon_by_code[each] = icon end
  end
end

local function minutes(clock)
  local hour, minute, half = (clock or ""):match("(%d+):(%d+)%s*([AP]M)")
  if not hour then return nil end
  return (tonumber(hour) % 12 + (half == "PM" and 12 or 0)) * 60 + tonumber(minute)
end

local function is_night(observed, astronomy)
  local now, sunrise, sunset = minutes(observed), minutes(astronomy.sunrise), minutes(astronomy.sunset)
  if not (now and sunrise and sunset) then return false end
  return now < sunrise or now > sunset
end

local function icon_for(code, night)
  if code == 113 then return night and icons.bedtime or icons.clear_day end
  if code == 116 then return night and icons.partly_cloudy_night or icons.partly_cloudy_day end
  return icons[icon_by_code[code] or "cloud"]
end

local function url_escape(text)
  return (text:gsub("[^%w%-._~]", function(char) return string.format("%%%02X", char:byte()) end))
end

local function location_query(place)
  local parts = {}
  for _, part in ipairs({ place.city or "", place.region or "" }) do
    table.insert(parts, (url_escape(part):gsub("%%20", "+")))
  end
  return table.concat(parts, "+")
end

local weather = {}

function weather.current(callback)
  sbar.exec(CURL .. " https://ipinfo.io/json", function(place)
    if type(place) ~= "table" then return callback(nil) end
    sbar.exec(CURL .. " 'https://wttr.in/" .. location_query(place) .. "?format=j1'", function(report)
      local ok, data = pcall(function()
        local now = report.current_condition[1]
        local astronomy = report.weather[1].astronomy[1]
        return {
          icon = icon_for(tonumber(now.weatherCode), is_night(now.localObsDateTime, astronomy)),
          temp = now.temp_C .. "°C",
          desc = now.weatherDesc[1].value,
          location = place.city,
          moon = astronomy.moon_phase,
        }
      end)
      callback(ok and data or nil)
    end)
  end)
end

local item = sbar.add("item", "weather", {
  position = "right",
  update_freq = 1800,
  icon = { string = icons.cloud, color = colors.secondary },
})

local function update()
  weather.current(function(data)
    if data then item:set({ icon = { string = data.icon }, label = { string = data.temp } }) end
  end)
end

item:subscribe({ "routine", "forced", "system_woke" }, update)
update()

return weather
