local settings = require("settings")
local colors = require("colors")

-- Equivalent to the --default domain
sbar.default({
  updates = "when_shown",
  icon = {
    font = {
      family = settings.font.text,
      style = settings.font.style_map["Bold"],
      size = 14.0
    },
    color = colors.white,
    padding_left = settings.paddings,
    padding_right = settings.paddings,
    background = { image = { corner_radius = 12 } },
  },
  label = {
    font = {
      family = settings.font.text,
      style = settings.font.style_map["Semibold"],
      size = 13.0
    },
    color = colors.white,
    padding_left = settings.paddings,
    padding_right = settings.paddings,
  },
  -- The frosted pill. corner_radius 12 against a 28px height gives a proper
  -- squircle rather than a rounded rectangle; the 1px rim replaces the old 2px
  -- border, which fought the blur for attention.
  background = {
    -- 24, not 28: centred on the indicator a 28 pill would sit 3px from the
    -- screen edge. This also matches the workspace bracket's height.
    height = 24,
    corner_radius = 12,
    border_width = 1,
    border_color = colors.bg2,
    image = {
      corner_radius = 12,
      border_color = colors.bg2,
      border_width = 1
    }
  },
  blur_radius = 60,
  popup = {
    background = {
      border_width = 1,
      corner_radius = 12,
      border_color = colors.popup.border,
      color = colors.popup.bg,
      shadow = { drawing = true },
    },
    blur_radius = 50,
  },
  padding_left = 5,
  padding_right = 5,
  scroll_texts = true,
})
