local colors = require("colors")
local settings = require("settings")

local SCRIPT = "~/.config/sketchybar/plugins/aerospace_spaces.sh"

-- Each workspace shows the native icons of its apps. SketchyBar draws an app
-- icon as an item's background image, one per item, so every workspace gets a
-- fixed row of icon slots that the script fills or hides. Keep in sync with
-- MAX_APPS in aerospace_spaces.sh.
local MAX_APPS = 6

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
    label = { drawing = false },
    background = { drawing = false },
    padding_left = 0,
    padding_right = 0,
    click_script = "aerospace workspace " .. ws,
  })

  local members = { "space." .. ws }
  for k = 1, MAX_APPS do
    local name = "space." .. ws .. ".app." .. k
    sbar.add("item", name, {
      position = "left",
      drawing = false,
      icon = { drawing = false },
      label = { drawing = false },
      -- Override the default pill from default.lua, or every icon gets its
      -- own bordered tile.
      background = {
        drawing = true,
        color = colors.transparent,
        border_width = 0,
        corner_radius = 0,
        image = { scale = 0.6, corner_radius = 0, border_width = 0 },
      },
      padding_left = 2,
      padding_right = 2,
      click_script = "aerospace workspace " .. ws,
    })
    members[#members + 1] = name
  end

  -- Each workspace is its own pill, styled like the widgets on the right
  -- (bg1 fill, bg2 rim, from default.lua). The script recolours the rim of
  -- the focused one.
  sbar.add("bracket", "space." .. ws .. ".chip", members, {
    background = { color = colors.bg1 },
  })

  -- Gap after the pill, as the widgets have. The script hides it along with
  -- an empty workspace.
  sbar.add("item", "space." .. ws .. ".gap", {
    position = "left",
    width = settings.group_paddings,
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

sbar.add("item", "spaces.padding", {
  position = "left",
  width = settings.group_paddings,
})
