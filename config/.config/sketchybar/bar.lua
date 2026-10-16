local colors = require("colors")

-- The tablet is a small secondary screen with no notch and an auto-hidden menu
-- bar, so the bar would only cost it rows: keep the bar off it and let windows
-- run to the top edge (AeroSpace gives that monitor a plain 5px top gap).
-- sketchybar only knows displays by arrangement id, so the name is resolved
-- through AeroSpace, whose NSScreen index follows the same order.
local BARLESS_MONITOR = "Any Display"
local LIST_MONITORS = "aerospace list-monitors"
  .. " --format '%{monitor-appkit-nsscreen-screens-id}|%{monitor-name}'"

---@param monitors string one "id|name" line per monitor
---@return string display value for sbar.bar
local function barDisplays(monitors)
  local ids = {}
  for id, name in (monitors or ""):gmatch("(%d+)|([^\n]*)") do
    if not name:find(BARLESS_MONITOR, 1, true) then
      table.insert(ids, id)
    end
  end
  return #ids > 0 and table.concat(ids, ",") or "all"
end

-- Resolved synchronously so the bar is created on the right displays: moving
-- it with a second message during startup intermittently crashes sketchybar.
local pipe = io.popen(LIST_MONITORS .. " 2>/dev/null")
local display = barDisplays(pipe and pipe:read("a"))
if pipe then
  pipe:close()
end

sbar.bar({
  height = 38,
  color = colors.bar.bg,
  -- macOS draws its screen-recording/mic privacy dot in the top-right corner,
  -- above every window including this bar, so the last pill needs room to sit
  -- clear of it rather than under it.
  padding_right = 30,
  padding_left = 10,
  position = "top",
  display = display,   -- every monitor except the tablet
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

local displayWatcher = sbar.add("item", "display_watcher", { drawing = false, updates = true })
displayWatcher:subscribe("display_change", function()
  sbar.exec(LIST_MONITORS, function(monitors)
    local changed = barDisplays(monitors)
    if changed ~= display then
      display = changed
      sbar.bar({ display = display })
    end
  end)
end)
