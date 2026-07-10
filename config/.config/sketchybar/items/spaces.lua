local colors = require("colors")
local settings = require("settings")

local SCRIPT = "~/.config/sketchybar/plugins/aerospace_spaces.sh"

for i = 1, 9 do
  local ws = tostring(i)

  local space = sbar.add("item", "space." .. ws, {
    position = "left",
    drawing = true,
    update_freq = 5,
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
    background = {
      color = colors.bg1,
      border_color = colors.bg2,
      border_width = 1,
      height = 26,
      corner_radius = 5,
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
