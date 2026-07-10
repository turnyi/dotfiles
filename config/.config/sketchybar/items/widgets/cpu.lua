local colors = require("colors")
local settings = require("settings")

local cpu = sbar.add("item", "widgets.cpu", {
  position = "right",
  update_freq = 5,
  icon = {
    string = "\xef\x80\x93",
    font = { family = settings.font.text, style = "Regular", size = 14.0 },
    color = colors.blue,
  },
  label = {
    string = "??%",
    font = {
      family = settings.font.numbers,
      style = settings.font.style_map["Bold"],
      size = 11.0,
    },
    color = colors.white,
  },
  padding_right = settings.paddings,
})

cpu:subscribe({ "routine", "system_woke" }, function()
  sbar.exec("top -l 1 -s 0 | awk '/CPU usage/{gsub(/%/,\"\",$3); printf \"%.0f\", $3}'", function(result)
    local pct = tonumber(result:match("%d+")) or 0
    local color = colors.blue
    if pct > 80 then
      color = colors.red
    elseif pct > 50 then
      color = colors.orange
    elseif pct > 30 then
      color = colors.yellow
    end
    cpu:set({ label = { string = pct .. "%", color = color } })
  end)
end)

cpu:subscribe("mouse.clicked", function()
  sbar.exec("open -a 'Activity Monitor'")
end)

sbar.add("bracket", "widgets.cpu.bracket", { cpu.name }, {
  background = { color = colors.bg1 },
})

sbar.add("item", "widgets.cpu.padding", {
  position = "right",
  width = settings.group_paddings,
})
