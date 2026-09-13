local terminal       = "kitty"
local browser        = "google-chrome-stable"
local fileManager    = "dolphin"
local discord        = "discord"
local menu           = "vicinae toggle"
local music          = "YouTube Music"
local clipboard      = "vicinae deeplink vicinae://launch/clipboard/history"
local notificationHistory = "vicinae cmd launch @turnyi/notification-history:history"
local postman        = "postman"
local screenRecorder = "wf-recorder-gui"

local chromeCentinel = "Profile 5"
local chromeOptitask = "Profile 1"
local chromePersonal = "Default"

package.path = os.getenv("HOME") .. "/.config/hypr/lua/?.lua;" .. package.path
require("centermaster").setup({})

local mainMod = "SUPER"

local function focus_or_launch(query)
  return hl.dsp.exec_cmd(string.format('bash ~/scripts/focus-or-lunch.sh "%s"', query))
end

local function chrome_profile(profile)
  return hl.dsp.exec_cmd(string.format('bash ~/scripts/chrome-profile-focus.sh "%s"', profile))
end

local function chrome_new_tab(profile)
  return hl.dsp.exec_cmd(string.format('%s --profile-directory="%s" about:blank', browser, profile))
end

------------------
---- MONITORS ----
------------------

for _, out in ipairs({ "DP-1", "DP-2", "DP-3", "DP-4" }) do
  hl.monitor({ output = out, mode = "5120x1440@120", position = "auto", scale = 1 })
end
hl.monitor({ output = "", mode = "preferred", position = "auto", scale = 1 })

local g9 = "desc:Samsung Electric Company LC49G95T H4ZT100019"

-- Pinned: "auto" monitors re-flow around the tablet output, which pushed the
-- G9 out from above it as soon as TAB appeared.
local side = { width = 1920 }
local main = { x = side.width, width = 5120, height = 1440 }
local tab = { width = 2960, height = 1848, scale = 2 }

hl.monitor({ output = "desc:Audio Processing Technology  Ltd MNN", mode = "preferred", position = "0x0", scale = 1 })
hl.monitor({ output = g9, mode = "5120x1440@120", position = main.x .. "x0", scale = 1 })
hl.monitor({
  output   = "TAB",
  mode     = tab.width .. "x" .. tab.height .. "@120",
  position = string.format("%dx%d", math.floor(main.x + (main.width - tab.width / tab.scale) / 2), main.height),
  scale    = tab.scale,
})

hl.workspace_rule({
  workspace = "m[" .. g9 .. "]",
  layout    = "lua:centermaster",
})

-------------------------------
---- ENVIRONMENT VARIABLES ----
-------------------------------

hl.env("QT_STYLE_OVERRIDE", "fusion")
hl.env("XCURSOR_SIZE", "24")
hl.env("HYPRCURSOR_SIZE", "24")
hl.env("WLR_RENDERER_ALLOW_SOFTWARE", "0")
hl.env("QT_QPA_PLATFORMTHEME", "qt6ct")

-----------------------
---- LOOK AND FEEL ----
-----------------------

hl.config({
  cursor = {
    inactive_timeout = 3,
  },

  general = {
    gaps_in     = 5,
    gaps_out    = 5,
    border_size = 1,
    col = {
      active_border   = { colors = { "rgba(4c5bffdd)", "rgba(3cc8ccdd)" }, angle = 45 },
      inactive_border = "rgba(3a3a4add)",
    },
    resize_on_border = false,
    allow_tearing    = false,
    layout           = "dwindle",
  },

  decoration = {
    rounding = 10,
    shadow = {
      enabled      = true,
      range        = 4,
      render_power = 3,
      color        = "rgba(1a1a1aee)",
    },
    blur = {
      enabled        = true,
      size           = 8,
      ignore_opacity = true,
      passes         = 3,
      noise          = 0.01,
      vibrancy       = 0.1696,
    },
  },

  animations = {
    enabled = false,
  },

  -- pseudotile was dropped in 0.56 — pseudotiling is dispatcher-only now
  -- (hl.dsp.window.pseudo()).
  dwindle = {
    preserve_split = true,
  },

  master = {
    new_status              = "master",
    new_on_top              = true,
    always_keep_position    = true,
    orientation             = "center",
    slave_count_for_center_master = 0,
    mfact                   = 0.45,
  },

  misc = {
    force_default_wallpaper = 1,
    disable_hyprland_logo   = true,
  },

  input = {
    kb_layout    = "us",
    kb_variant   = "",
    kb_model     = "",
    kb_options   = "",
    kb_rules     = "",
    follow_mouse = 1,
    sensitivity  = 0,
    touchpad = {
      natural_scroll = false,
    },
  },
})

-- Curves are still defined even though animations are disabled, so flipping
-- animations.enabled back on does not land on missing bezier names.
hl.curve("easeOutQuint",   { type = "bezier", points = { { 0.23, 1 },   { 0.32, 1 } } })
hl.curve("easeInOutCubic", { type = "bezier", points = { { 0.65, 0.05 }, { 0.36, 1 } } })
hl.curve("linear",         { type = "bezier", points = { { 0, 0 },      { 1, 1 } } })
hl.curve("almostLinear",   { type = "bezier", points = { { 0.5, 0.5 },  { 0.75, 1.0 } } })
hl.curve("quick",          { type = "bezier", points = { { 0.15, 0 },   { 0.1, 1 } } })

hl.device({ name = "epic-mouse-v1", sensitivity = -0.5 })

---------------------
---- KEYBINDINGS ----
---------------------

hl.bind(mainMod .. " + T",         focus_or_launch(terminal))
hl.bind(mainMod .. " + SHIFT + T", hl.dsp.exec_cmd(terminal))

hl.bind(mainMod .. " + B",         chrome_profile(chromePersonal))
hl.bind(mainMod .. " + SHIFT + B", chrome_new_tab(chromePersonal))
hl.bind(mainMod .. " + F",         chrome_profile(chromeCentinel))
hl.bind(mainMod .. " + SHIFT + F", chrome_new_tab(chromeCentinel))

hl.bind(mainMod .. " + E",         focus_or_launch(fileManager))
hl.bind(mainMod .. " + SHIFT + E", hl.dsp.exec_cmd(fileManager))
hl.bind(mainMod .. " + W",         focus_or_launch("whatsapp"))
hl.bind(mainMod .. " + N",         hl.dsp.exec_cmd(notificationHistory))
hl.bind(mainMod .. " + SHIFT + N", hl.dsp.exec_cmd("swaync-client -t"))
hl.bind(mainMod .. " + D",         focus_or_launch(discord))
hl.bind(mainMod .. " + M",         focus_or_launch(music))
hl.bind(mainMod .. " + P",         focus_or_launch(postman))
hl.bind(mainMod .. " + U",         focus_or_launch("com.anthropic.claude-desktop"))
hl.bind(mainMod .. " + SHIFT + U", hl.dsp.exec_cmd("claude-desktop"))
hl.bind(mainMod .. " + G",         hl.dsp.exec_cmd(screenRecorder))
hl.bind(mainMod .. " + S",         focus_or_launch("slack"))
hl.bind(mainMod .. " + C",         hl.dsp.exec_cmd(clipboard))
hl.bind(mainMod .. " + R",         hl.dsp.exec_cmd(menu))

hl.bind(mainMod .. " + Q", hl.dsp.window.close())
hl.bind(mainMod .. " + V", hl.dsp.window.float({ action = "toggle" }))
hl.bind(mainMod .. " + I", hl.dsp.exec_cmd("killall waybar || waybar"), { release = true })
hl.bind(mainMod .. " + SHIFT + D", hl.dsp.exec_cmd("bash ~/scripts/tablet-screen.sh toggle"))
hl.bind(mainMod .. " + SHIFT + M", hl.dsp.exec_cmd("systemctl suspend & hyprlock"))

for key, dir in pairs({ left = "left", right = "right", up = "up", down = "down",
                        h = "left", l = "right", k = "up", j = "down" }) do
  hl.bind(mainMod .. " + " .. key, hl.dsp.focus({ direction = dir }))
end

local function per_layout(centermaster_msg, fallback)
  return function()
    local ws = hl.get_active_workspace()
    if ws and ws.tiled_layout == "lua:centermaster" then
      hl.dispatch(hl.dsp.layout(centermaster_msg))
    elseif fallback then
      hl.dispatch(fallback)
    end
  end
end

-- movewindow is a no-op under a custom lua layout (the layout API exposes no
-- hook for it), so moving windows goes through messages centermaster
-- implements itself.
for key, dir in pairs({ H = "left", L = "right", K = "up", J = "down" }) do
  hl.bind(mainMod .. " + SHIFT + " .. key,
    per_layout("move" .. dir, hl.dsp.window.move({ direction = dir })))
end
hl.bind(mainMod .. " + SHIFT + Return", per_layout("swapmaster"))

-- Accordion: A toggles the column holding the focused window (both columns from
-- the master); the bracket keys target a side directly.
hl.bind(mainMod .. " + A", per_layout("toggleaccordion"))
hl.bind(mainMod .. " + SHIFT + A", per_layout("toggleaccordionboth"))
hl.bind(mainMod .. " + bracketleft",  per_layout("toggleaccordionleft"))
hl.bind(mainMod .. " + bracketright", per_layout("toggleaccordionright"))
hl.bind(mainMod .. " + CTRL + A",     per_layout("sendotherside"))
hl.bind(mainMod .. " + CTRL + SHIFT + L",
  per_layout("mfact+", hl.dsp.window.resize({ x = 40, y = 0 })))
hl.bind(mainMod .. " + CTRL + SHIFT + H",
  per_layout("mfact-", hl.dsp.window.resize({ x = -40, y = 0 })))

for key, delta in pairs({ k = { 0, -40 }, j = { 0, 40 } }) do
  hl.bind(mainMod .. " + CTRL + " .. key,
    hl.dsp.window.resize({ x = delta[1], y = delta[2] }), { repeating = true })
end

hl.bind(mainMod .. " + CTRL + H", hl.dsp.workspace.move({ monitor = "l" }))
hl.bind(mainMod .. " + CTRL + L", hl.dsp.workspace.move({ monitor = "r" }))

for i = 1, 10 do
  local key = i % 10
  hl.bind(mainMod .. " + " .. key,             hl.dsp.focus({ workspace = i }))
  hl.bind(mainMod .. " + SHIFT + " .. key,     hl.dsp.window.move({ workspace = i }))
end

hl.bind(mainMod .. " + mouse_down", hl.dsp.focus({ workspace = "e+1" }))
hl.bind(mainMod .. " + mouse_up",   hl.dsp.focus({ workspace = "e-1" }))

hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag(),   { mouse = true })
hl.bind(mainMod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

hl.bind("SUPER + X",         hl.dsp.exec_cmd('grim -g "$(slurp)" - | wl-copy'))
hl.bind("SUPER + SHIFT + S", hl.dsp.exec_cmd('grim -g "$(slurp)" - | swappy -f -'))
hl.bind("SUPER + SHIFT + R", hl.dsp.exec_cmd("kooha"))

hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"), { locked = true, repeating = true })
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"),      { locked = true, repeating = true })
hl.bind("XF86AudioMute",        hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"),     { locked = true, repeating = true })
hl.bind("XF86AudioMicMute",     hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"),   { locked = true, repeating = true })
hl.bind("XF86MonBrightnessDown",hl.dsp.exec_cmd("brightnessctl s 10%-"),                           { locked = true, repeating = true })
hl.bind("XF86MonBrightnessUp",  hl.dsp.exec_cmd("brightnessctl s +10%"),                           { locked = true, repeating = true })

hl.bind("XF86AudioNext",  hl.dsp.exec_cmd("playerctl next"),       { locked = true })
hl.bind("XF86AudioPause", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPlay",  hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPrev",  hl.dsp.exec_cmd("playerctl previous"),   { locked = true })

hl.bind("switch:on:Lid Switch",  hl.dsp.exec_cmd("hyprctl keyword monitor eDP-1, disable"), { locked = true })
hl.bind("switch:off:Lid Switch", hl.dsp.exec_cmd("hyprctl keyword monitor eDP-1,preferred,0x0,1"), { locked = true })

-- SUPER+O opened the Optitask Chrome profile AND entered the "nomovment" submap
-- in hyprland.conf; the submap bind came last and won, so O never reached
-- Chrome. Kept as the submap, with Optitask moved to SUPER+SHIFT+O.
hl.define_submap("nomovment", "reset", function()
  hl.bind("escape", hl.dsp.submap("reset"))
end)
hl.bind(mainMod .. " + O",         hl.dsp.submap("nomovment"))
hl.bind(mainMod .. " + SHIFT + O", chrome_profile(chromeOptitask))

--------------------------------
---- WINDOWS AND WORKSPACES ----
--------------------------------

hl.window_rule({
  name  = "suppress-maximize-events",
  match = { class = ".*" },
  suppress_event = "maximize",
})

hl.window_rule({
  name  = "fix-xwayland-drags",
  match = { class = "^$", title = "^$", xwayland = true },
  float      = true,
  fullscreen = false,
  no_focus   = true,
})

hl.window_rule({
  name  = "ulauncher-stay-focused",
  match = { class = "^(ulauncher)$" },
  stay_focused = true,
})

hl.window_rule({
  name  = "pf-menu-float",
  match = { class = "^(pf-menu)$" },
  float  = true,
  center = true,
})

-- Google Meet picture-in-picture. Chrome opens it as a floating window whose
-- title is "Meet - <name>" with no " - Google Chrome" suffix — a normal Chrome
-- window keeps that suffix, so float + the Meet prefix is what tells them apart.
hl.window_rule({
  name  = "meet-pip-corner",
  match = { class = "^(google-chrome)$", float = true, title = "^(Meet - .*)$" },
  size = "640 360",
  move = "100%-650 61",
  pin  = true,
})

-------------------
---- AUTOSTART ----
-------------------

hl.on("hyprland.start", function()
  hl.exec_cmd("hyprpaper")
  hl.exec_cmd("dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP")
  hl.exec_cmd("walker --gapplication-service")
  hl.exec_cmd("hypridle")
  hl.exec_cmd("vicinae server")
  hl.exec_cmd("~/scripts/notification-recorder.py")
  hl.exec_cmd("espanso daemon")
  hl.exec_cmd("eww daemon")
  hl.exec_cmd('gsettings set org.gnome.desktop.interface color-scheme "prefer-dark"')
end)
