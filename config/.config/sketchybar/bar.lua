local colors = require("colors")

sbar.bar({
  height = 32,
  color = colors.bar.bg,
  padding_right = 8,
  padding_left = 8,
  position = "top",
  display = "all",     -- show the bar on every monitor
  topmost = "window",  -- draw above regular windows so it is never hidden
})
