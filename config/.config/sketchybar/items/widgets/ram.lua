local colors = require("colors")
local settings = require("settings")

local ram = sbar.add("item", "widgets.ram", {
  position = "right",
  update_freq = 5,
  icon = {
    string = "\xef\x87\x80",
    font = { family = settings.font.text, style = "Regular", size = 14.0 },
    color = colors.blue,
  },
  label = {
    string = "?/?G",
    font = {
      family = settings.font.numbers,
      style = settings.font.style_map["Bold"],
      size = 11.0,
    },
    color = colors.white,
  },
  padding_right = settings.paddings,
})

ram:subscribe({ "routine", "system_woke" }, function()
  sbar.exec(
    "total=$(sysctl -n hw.memsize); vm_stat | awk -v total=$total '/page size of/{ps=$8}/Pages active/{a=$3}/Pages wired/{w=$4} END{used=(a+w)*ps; printf \"%.1f %.0f %.0f\", used/1073741824, total/1073741824, used*100/total}'",
    function(result)
      local used, total, pct = result:match("([%d%.]+)%s+([%d%.]+)%s+([%d%.]+)")
      pct = tonumber(pct) or 0
      local color = colors.blue
      if pct > 80 then
        color = colors.red
      elseif pct > 60 then
        color = colors.orange
      end
      ram:set({ label = { string = (used or "?") .. "/" .. (total or "?") .. "G", color = color } })
    end
  )
end)

ram:subscribe("mouse.clicked", function()
  sbar.exec("open -a 'Activity Monitor'")
end)

sbar.add("bracket", "widgets.ram.bracket", { ram.name }, {
  background = { color = colors.bg1 },
})

sbar.add("item", "widgets.ram.padding", {
  position = "right",
  width = settings.group_paddings,
})
