require("items.spaces")
require("items.front_app")
require("items.spotify")
require("items.attention")
require("items.clock")
require("items.battery")
require("items.volume")
require("items.mail")
require("items.discord")
require("items.pomodoro")
require("items.weather")

sbar.add("bracket", "status", { "battery", "volume", "mail", "discord", "pomodoro" }, {
  background = { color = require("colors").surface_container },
})
