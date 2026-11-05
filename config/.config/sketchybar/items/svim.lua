local colors = require("colors")
local settings = require("settings")

local MODES = {
  N = { label = "NORMAL", color = colors.green },
  V = { label = "VISUAL", color = colors.orange },
  C = { label = "COMMAND", color = colors.yellow },
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
