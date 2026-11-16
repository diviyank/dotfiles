------------------
---- MONITORS ----
------------------

-- kanshi handles multi-monitor — leave this as default or configure per setup
-- hl.monitor({ output = "", mode = "preferred", position = "auto", scale = "auto" })
hl.monitor({ output = "HDMI-A-1", mode = "2560x1440@59.95", position = "0x0",    scale = 1 })
hl.monitor({ output = "DP-1",     mode = "1920x1080@239.76", position = "2560x180", scale = 1 })


-------------------
---- AUTOSTART ----
-------------------

hl.on("hyprland.start", function()
    hl.exec_cmd("/usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1")
    hl.exec_cmd("nm-applet --indicator")
    hl.exec_cmd("/home/diviyan/.local/bin/pypr")
    hl.exec_cmd("caelestia shell -d")
    hl.exec_cmd("wl-paste --type text --watch cliphist store")
    hl.exec_cmd("wl-paste --type image --watch cliphist store")
    hl.exec_cmd("discord")
    hl.exec_cmd("flameshot")
    hl.exec_cmd("mailspring")
    hl.exec_cmd("sleep 30 && spotify")
    hl.exec_cmd("xset r rate 270 70") -- works if Xwayland is running
end)


-------------------
---- VARIABLES ----
-------------------

local mod             = "SUPER"
local terminal        = "kitty --session ~/.config/kitty/tmux_session.conf"
local editor          = "kitty --config ~/.config/kitty/kitty_nvim.conf --session ~/.config/kitty/tmux_session.conf"
local scratchpad_term = "kitty --class scratchpad --session ~/.config/kitty/tmux_session.conf"


-------------------------------
---- ENVIRONMENT VARIABLES ----
-------------------------------

hl.env("XCURSOR_SIZE", "24")
hl.env("HYPRCURSOR_SIZE", "24")

-- AMD GPU — force vulkan/wayland
hl.env("WLR_RENDERER", "vulkan")
hl.env("AMD_VULKAN_ICD", "RADV")
hl.env("LIBVA_DRIVER_NAME", "radeonsi") -- hardware video decode
hl.env("VDPAU_DRIVER", "radeonsi")


-----------------------
---- LOOK AND FEEL ----
-----------------------

hl.config({
    general = {
        gaps_in          = 5,
        gaps_out         = 10,
        border_size      = 0, -- matches your `border pixel 0`
        layout           = "dwindle",
        resize_on_border = true,
    },

    decoration = {
        rounding = 12,

        blur = {
            enabled  = true,
            size              = 6,
            passes            = 3,
            vibrancy          = 0.2,
            ignore_opacity    = true,
            new_optimizations = true,
            popups            = true,
        },

        shadow = {
            enabled      = true,
            range        = 20,
            render_power = 3,
            color        = "rgba(0000004d)",
        },
    },

    animations = {
        enabled = true,
    },

    dwindle = {
        preserve_split = true,
    },

    misc = {
        disable_hyprland_logo    = true,
        disable_splash_rendering = true,
        focus_on_activate        = true,
    },

    input = {
        follow_mouse = 0, -- no focus on hover
        kb_layout    = "us",
        kb_variant   = "altgr-intl",
        kb_options   = "nodeadkeys",
        repeat_rate  = 70,
        repeat_delay = 270,
    },
})

hl.curve("emphasizedAccel", { type = "bezier", points = { {0.3,  0},   {0.8, 0.15} } })
hl.curve("emphasizedDecel", { type = "bezier", points = { {0.05, 0.7}, {0.1, 1}    } })
hl.curve("standard",        { type = "bezier", points = { {0.2,  0},   {0,   1}    } })

hl.animation({ leaf = "layersIn",    enabled = true, speed = 5, bezier = "emphasizedDecel", style = "slide" })
hl.animation({ leaf = "layersOut",   enabled = true, speed = 4, bezier = "emphasizedAccel", style = "slide" })
hl.animation({ leaf = "fadeLayers",  enabled = true, speed = 5, bezier = "standard" })
hl.animation({ leaf = "windowsIn",   enabled = true, speed = 5, bezier = "emphasizedDecel" })
hl.animation({ leaf = "windowsOut",  enabled = true, speed = 3, bezier = "emphasizedAccel" })
hl.animation({ leaf = "windowsMove", enabled = true, speed = 2.5, bezier = "standard" })
hl.animation({ leaf = "workspaces",  enabled = true, speed = 2.5, bezier = "emphasizedDecel", style = "slide" })
hl.animation({ leaf = "fade",        enabled = true, speed = 6, bezier = "standard" })
hl.animation({ leaf = "border",      enabled = true, speed = 6, bezier = "standard" })


---------------------
---- KEYBINDINGS ----
---------------------

-- Directions (matching your vim-style: j=left, k=down, l=up, ;=right)
local left, down, up, right = "j", "k", "l", "semicolon"

-- Apps
hl.bind(mod .. " + Return",         hl.dsp.exec_cmd(terminal))
hl.bind(mod .. " + SHIFT + Return", hl.dsp.exec_cmd(editor))
hl.bind(mod .. " + SPACE",          hl.dsp.exec_cmd("caelestia shell drawers toggle launcher"))
hl.bind("ALT + C",                  hl.dsp.exec_cmd("pkill fuzzel || caelestia clipboard"))
hl.bind(mod .. " + SHIFT + Q",      hl.dsp.window.close())

-- Fullscreen / floating
hl.bind(mod .. " + F",             hl.dsp.window.fullscreen({ mode = "fullscreen", action = "toggle" }))
hl.bind(mod .. " + SHIFT + SPACE", hl.dsp.window.float({ action = "toggle" }))

-- Layouts
hl.bind(mod .. " + S", hl.dsp.layout("orientationcenter")) -- closest to stacking
hl.bind(mod .. " + W", hl.dsp.layout("orientationtop"))    -- closest to tabbed
hl.bind(mod .. " + E", hl.dsp.layout("togglesplit"))
hl.bind(mod .. " + H", hl.dsp.layout("splith"))
hl.bind(mod .. " + V", hl.dsp.layout("splitv"))

-- Focus
hl.bind(mod .. " + " .. left,  hl.dsp.focus({ direction = "left" }))
hl.bind(mod .. " + " .. down,  hl.dsp.focus({ direction = "down" }))
hl.bind(mod .. " + " .. up,    hl.dsp.focus({ direction = "up" }))
hl.bind(mod .. " + " .. right, hl.dsp.focus({ direction = "right" }))
hl.bind(mod .. " + left",      hl.dsp.focus({ direction = "left" }))
hl.bind(mod .. " + down",      hl.dsp.focus({ direction = "down" }))
hl.bind(mod .. " + up",        hl.dsp.focus({ direction = "up" }))
hl.bind(mod .. " + right",     hl.dsp.focus({ direction = "right" }))

-- Move windows
hl.bind(mod .. " + SHIFT + " .. left,  hl.dsp.window.move({ direction = "left" }))
hl.bind(mod .. " + SHIFT + " .. up,    hl.dsp.window.move({ direction = "up" }))
hl.bind(mod .. " + SHIFT + " .. right, hl.dsp.window.move({ direction = "right" }))
hl.bind(mod .. " + SHIFT + left",      hl.dsp.window.move({ direction = "left" }))
hl.bind(mod .. " + SHIFT + down",      hl.dsp.window.move({ direction = "down" }))
hl.bind(mod .. " + SHIFT + up",        hl.dsp.window.move({ direction = "up" }))
hl.bind(mod .. " + SHIFT + right",     hl.dsp.window.move({ direction = "right" }))

-- -- Move window to other monitor
-- hl.bind(mod .. " + SHIFT + CTRL + left",  hl.dsp.window.move({ monitor = "-1" }))
-- hl.bind(mod .. " + SHIFT + CTRL + right", hl.dsp.window.move({ monitor = "+1" }))

-- Focus parent (Hyprland doesn't have this natively, approximate)
hl.bind(mod .. " + A", hl.dsp.group.next())

-- Resize mode (submap = i3's mode)
hl.define_submap("resize", function()
    hl.bind(left,      hl.dsp.window.resize({ x = -30, y = 0 }), { repeating = true })
    hl.bind(right,     hl.dsp.window.resize({ x = 30,  y = 0 }), { repeating = true })
    hl.bind(up,        hl.dsp.window.resize({ x = 0,   y = -30 }), { repeating = true })
    hl.bind(down,      hl.dsp.window.resize({ x = 0,   y = 30 }), { repeating = true })
    hl.bind("left",    hl.dsp.window.resize({ x = -30, y = 0 }), { repeating = true })
    hl.bind("right",   hl.dsp.window.resize({ x = 30,  y = 0 }), { repeating = true })
    hl.bind("up",      hl.dsp.window.resize({ x = 0,   y = -30 }), { repeating = true })
    hl.bind("down",    hl.dsp.window.resize({ x = 0,   y = 30 }), { repeating = true })
    hl.bind("Return",  hl.dsp.submap("reset"))
    hl.bind("Escape",  hl.dsp.submap("reset"))
    hl.bind(mod .. " + R", hl.dsp.submap("reset"))
end)
hl.bind(mod .. " + R", hl.dsp.submap("resize"))

-- Or use the special workspace scratchpad:
hl.bind(mod .. " + SHIFT + minus", hl.dsp.window.move({ workspace = "special:scratch" }))
hl.bind(mod .. " + minus",         hl.dsp.workspace.toggle_special("scratch"))

-- Workspaces 1–10, plus extra workspaces 11–16 (A–F)
local workspaceKeys = { "1", "2", "3", "4", "5", "6", "7", "8", "9", "0",
                        "Insert", "Home", "Prior", "Delete", "End", "Next" }

for i, key in ipairs(workspaceKeys) do
    hl.bind(mod .. " + " .. key,             hl.dsp.focus({ workspace = i }))
    hl.bind(mod .. " + SHIFT + " .. key,     hl.dsp.window.move({ workspace = i }))
end

hl.bind(mod .. " + SHIFT + CTRL + left",  hl.dsp.workspace.move({ monitor = "l" }))
hl.bind(mod .. " + SHIFT + CTRL + right", hl.dsp.workspace.move({ monitor = "r" }))
hl.bind(mod .. " + SHIFT + CTRL + up",    hl.dsp.workspace.move({ monitor = "u" }))
hl.bind(mod .. " + SHIFT + CTRL + down",  hl.dsp.workspace.move({ monitor = "d" }))

-- Volume
hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("pamixer -i 10"), { locked = true, repeating = true })
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("pamixer -d 10"), { locked = true, repeating = true })
hl.bind("XF86AudioMute",        hl.dsp.exec_cmd("pamixer -t"),    { locked = true })
hl.bind("XF86AudioMicMute",     hl.dsp.exec_cmd("pamixer --default-source -t"), { locked = true })

-- Brightness
hl.bind("XF86MonBrightnessUp",   hl.dsp.exec_cmd("brightnessctl s 5%+"), { locked = true, repeating = true })
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("brightnessctl s 5%-"), { locked = true, repeating = true })

-- Media keys
hl.bind("Pause",         hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPlay", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("KP_Right",      hl.dsp.exec_cmd("playerctl next"),       { locked = true })
hl.bind("KP_Left",       hl.dsp.exec_cmd("playerctl previous"),   { locked = true })

-- Spotify via DBUS
local spotifyDbus = "dbus-send --print-reply --dest=org.mpris.MediaPlayer2.spotify /org/mpris/MediaPlayer2 org.mpris.MediaPlayer2.Player."
hl.bind(mod .. " + CTRL + down",  hl.dsp.exec_cmd(spotifyDbus .. "PlayPause"))
hl.bind(mod .. " + CTRL + right", hl.dsp.exec_cmd(spotifyDbus .. "Next"))
hl.bind(mod .. " + CTRL + left",  hl.dsp.exec_cmd(spotifyDbus .. "Previous"))

-- Screenshots (grim + slurp replaces flameshot on Wayland)
local screenshot = [[grim -g "$(slurp)" - | swappy -f -]]
hl.bind("Print",               hl.dsp.exec_cmd(screenshot))
hl.bind(mod .. " + SHIFT + K", hl.dsp.exec_cmd(screenshot))
hl.bind(mod .. " + SHIFT + apostrophe", hl.dsp.exec_cmd("~/.config/hypr/scripts/gif-record.sh"))

-- Screen lock
hl.bind(mod .. " + X", hl.dsp.global("caelestia:lock"))
hl.bind(mod .. " + D", hl.dsp.global("caelestia:dashboard"))
hl.bind(mod .. " + ALT + L", function()
    hl.dispatch(hl.dsp.exec_cmd("caelestia shell -d"))
    hl.dispatch(hl.dsp.global("caelestia:lock"))
end, { locked = true })

-- Keyboard layout switching
-- `hyprctl keyword` does not work with the Lua config manager, so set the
-- values natively instead.
hl.bind(mod .. " + SHIFT + U", function()
    hl.config({ input = { kb_variant = "altgr-intl", kb_options = "nodeadkeys" } })
end)
hl.bind(mod .. " + SHIFT + I", function()
    hl.config({ input = { kb_layout = "us", kb_variant = "", kb_options = "" } })
end)
hl.bind(mod .. " + SHIFT + T", function()
    hl.config({ input = { kb_layout = "de" } })
end)

-- Reload / restart
hl.bind(mod .. " + SHIFT + C", hl.dsp.exec_cmd("hyprctl reload"))
hl.bind(mod .. " + SHIFT + M", hl.dsp.exec_cmd("kanshi"))
hl.bind(mod .. " + SHIFT + E", hl.dsp.exec_cmd("~/.config/hypr/scripts/reload-session.sh"))

-- Exit
hl.bind(mod .. " + CTRL + SHIFT + E", hl.dsp.exit())

-- Drag floating windows
hl.bind(mod .. " + mouse:272", hl.dsp.window.drag(),   { mouse = true })
hl.bind(mod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

-- Scratchpad
hl.bind(mod .. " + tab", hl.dsp.exec_cmd("/home/diviyan/.local/bin/pypr toggle term"))


----------------------
---- WINDOW RULES ----
----------------------

hl.window_rule({ name = "ws4-slack",       match = { class = "Slack" },      workspace = 4 })
hl.window_rule({ name = "ws6-thunar",      match = { class = "Thunar" },     workspace = 6 })
hl.window_rule({ name = "ws6-discord",     match = { class = "discord" },    workspace = 6 })
hl.window_rule({ name = "ws7-mail",        match = { class = "(thunderbird|Thunderbird|betterbird|Mailspring|Mail)" }, workspace = 7 })
hl.window_rule({ name = "ws8-calendar",    match = { class = "(Morgen|MineTime)" }, workspace = 8 })
hl.window_rule({ name = "ws9-spotify",     match = { class = "Spotify" },    workspace = 9 })
hl.window_rule({ name = "ws13-protonmail", match = { class = "(ProtonMail Bridge|Protonmail Desktop)" }, workspace = 13 })
hl.window_rule({ name = "ws3-jetbrains",   match = { class = "(jetbrains-.*|Toolbox)" }, workspace = 3 })
hl.window_rule({ name = "no-client-maximize", match = { class = ".*" }, suppress_event = "maximize" })
