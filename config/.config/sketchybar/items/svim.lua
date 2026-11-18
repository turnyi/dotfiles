local settings = require("settings")

-- Same colors as the border (config/.config/svim/svim.sh) and Hyprland's vimmode.lua
local MODES = {
  N = { label = "NORMAL", color = 0xee9ed072 },
  V = { label = "VISUAL", color = 0xeef39660 },
  C = { label = "COMMAND", color = 0xeee7c664 },
}

sbar.add("event", "svim_mode")

local svim = sbar.add("item", "svim.mode", {
  position = "left",
  drawing = false,
  icon = {
    string = utf8.char(0xe62b),
    font = { family = settings.font.text, style = "Regular", size = 14.0 },
  },
  label = {
    font = { style = settings.font.style_map["Black"], size = 12.0 },
  },
  padding_left = settings.paddings,
  padding_right = settings.paddings,
})

svim:subscribe("svim_mode", function(env)
  local mode = MODES[env.MODE]
  if not mode then
    svim:set({ drawing = false })
    return
  end
  svim:set({
    drawing = true,
    icon = { color = mode.color },
    label = { string = mode.label, color = mode.color },
  })
end)
