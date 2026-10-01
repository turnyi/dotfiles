local colors = require("colors")

sbar.bar({
  height = 38,
  color = colors.bar.bg,
  -- macOS draws its screen-recording/mic privacy dot in the top-right corner,
  -- above every window including this bar, so the last pill needs room to sit
  -- clear of it rather than under it.
  padding_right = 30,
  padding_left = 10,
  position = "top",
  display = "all",     -- show the bar on every monitor
  topmost = "window",  -- draw above regular windows so it is never hidden
  -- The bar draws nothing itself; the pills float inside it. Height is 38
  -- against a 28px pill so there is real clearance above and below — the
  -- reference glues a 30px pill into a 32px bar, which reads as a toolbar
  -- stuck to the screen edge rather than as something floating over it.
  -- sketchybar centres every pill on the bar's vertical midpoint
  -- (y_offset + height/2). macOS draws its screen-recording indicator with its
  -- centre at ~16.8 logical px from the top, so the midpoint has to land there
  -- for the pills to line up with it: -2 + 38/2 = 17.
  y_offset = -2,
  shadow = false,
  sticky = true,
  font_smoothing = true,
})
