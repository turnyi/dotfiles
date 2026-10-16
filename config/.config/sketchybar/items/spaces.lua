local colors = require("colors")
local settings = require("settings")

local SCRIPT = "~/.config/sketchybar/plugins/aerospace_spaces.sh"

for i = 1, 9 do
  local ws = tostring(i)

  local space = sbar.add("item", "space." .. ws, {
    position = "left",
    drawing = true,
    update_freq = 5,
    -- Must be "on", not the inherited "when_shown". An empty workspace is
    -- hidden with drawing=off, and a hidden item under "when_shown" stops
    -- updating — so it could never notice it had gained a window and turn
    -- itself back on. Hidden would have meant hidden until the next reload.
    updates = true,
    icon = {
      string = ws,
      font = { family = settings.font.numbers, style = "Bold", size = 13.0 },
      color = colors.grey,
      padding_left = 10,
      padding_right = 4,
    },
    label = {
      string = "",
      font = "sketchybar-app-font:Regular:14.0",
      color = colors.grey,
      padding_right = 10,
      y_offset = -1,
    },
    -- No pill of its own: the whole row shares one frosted pill (the bracket
    -- below), and only the focused workspace draws a chip inside it. Nine
    -- bordered pills in a row read as nine competing objects; one pill with a
    -- highlight inside reads as one control with a current value.
    background = {
      color = colors.transparent,
      border_color = colors.transparent,
      border_width = 0,
      height = 20,
      corner_radius = 7,
    },
    padding_left = 2,
    padding_right = 2,
    click_script = "aerospace workspace " .. ws,
  })

  -- Initial render
  sbar.exec(SCRIPT .. " " .. ws)

  space:subscribe("aerospace_workspace_change", function(env)
    sbar.exec(SCRIPT .. " " .. ws)
  end)

  space:subscribe("front_app_switched", function(env)
    sbar.exec(SCRIPT .. " " .. ws .. " 0.4")
  end)

  space:subscribe("routine", function(env)
    sbar.exec(SCRIPT .. " " .. ws)
  end)
end

-- One frosted pill around the whole workspace row.
local space_names = {}
for i = 1, 9 do
  space_names[i] = "space." .. i
end

sbar.add("bracket", "spaces.bracket", space_names, {
  background = {
    color = colors.bg1,
    border_color = colors.bg2,
    border_width = 1,
    height = 24,
    corner_radius = 10,
  },
  blur_radius = 60,
})

sbar.add("item", "spaces.padding", {
  position = "left",
  width = settings.group_paddings,
})
