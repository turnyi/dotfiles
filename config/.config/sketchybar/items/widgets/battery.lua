local icons = require("icons")
local colors = require("colors")
local settings = require("settings")

local TABLET_SCRIPT = os.getenv("HOME") .. "/scripts/tablet-battery.sh"

-- glyph `tablet-android` in Hack Nerd Font v2. The Mac keeps the battery
-- glyphs, so the two charges sharing this pill never read as the same device.
-- The plain `tablet` glyph is a bare rectangle that reads as another battery
-- at this size; this one carries a home indicator, so it reads as a device.
local TABLET_ICON = utf8.char(0xf04f7)

-- Android's battery states that mean "a cable is doing the work". The rest
-- ("discharging", "unknown") are the tablet running itself down.
local TABLET_ON_POWER = {
  charging = true,
  full = true,
  not_charging = true,
}

local battery = sbar.add("item", "widgets.battery", {
  position = "right",
  icon = {
    font = {
      style = settings.font.style_map["Regular"],
      -- 19 made the bolt tower over the 14pt icons beside it.
      size = 15.0,
    }
  },
  label = { font = { family = settings.font.numbers } },
  update_freq = 180,
  popup = { align = "center" }
})

local remaining_time = sbar.add("item", {
  position = "popup." .. battery.name,
  icon = {
    string = "Time remaining:",
    width = 100,
    align = "left"
  },
  label = {
    string = "??:??h",
    width = 100,
    align = "right"
  },
})

-- The tablet used as a second screen, drawn only while it is attached. Added
-- after the battery so it lands to its left: the Mac's own charge keeps its
-- place beside the clock whether or not the tablet is there.
--
-- `updates = "on"` is load-bearing. The default is "when_shown", under which a
-- hidden item stops receiving events — it would hide once on an absent tablet
-- and never run again to notice one arriving.
local tablet = sbar.add("item", "widgets.battery.tablet", {
  position = "right",
  drawing = false,
  updates = "on",
  icon = {
    string = TABLET_ICON,
    font = { style = settings.font.style_map["Regular"], size = 15.0 },
  },
  label = { font = { family = settings.font.numbers } },
  update_freq = 60,
})

local function update_tablet()
  sbar.exec(TABLET_SCRIPT, function(out)
    local level, status = (out or ""):match("^(%d+)|([%a_]+)|")
    if not level then
      -- No tablet answering adb: the pill leaves no trace.
      tablet:set({ drawing = false })
      return
    end

    -- Same thresholds as the Mac's own charge above, so one colour means one
    -- thing across the pill no matter which device it is describing.
    local charge = tonumber(level)
    local color = colors.green
    if charge <= 20 then
      color = colors.red
    elseif charge <= 40 then
      color = colors.orange
    end

    -- The same plug the Mac shows when it is on power, so one symbol means one
    -- thing across the pill. It badges the tablet glyph rather than replacing
    -- it: the tablet is the only thing saying which device this row describes.
    local icon = TABLET_ICON
    if TABLET_ON_POWER[status] then
      icon = TABLET_ICON .. icons.battery.charging
    end

    local lead = charge < 10 and "0" or ""

    tablet:set({
      drawing = true,
      icon = { string = icon, color = color },
      label = { string = lead .. charge .. "%" },
    })
  end)
end

tablet:subscribe(
  { "routine", "forced", "system_woke", "power_source_change", "display_change" },
  update_tablet
)

battery:subscribe({"routine", "power_source_change", "system_woke"}, function()
  sbar.exec("pmset -g batt", function(batt_info)
    local icon = "!"
    local label = "?"

    local found, _, charge = batt_info:find("(%d+)%%")
    if found then
      charge = tonumber(charge)
      label = charge .. "%"
    end

    local color = colors.green
    local charging, _, _ = batt_info:find("AC Power")

    if charging then
      icon = icons.battery.charging
    else
      if found and charge > 80 then
        icon = icons.battery._100
      elseif found and charge > 60 then
        icon = icons.battery._75
      elseif found and charge > 40 then
        icon = icons.battery._50
      elseif found and charge > 20 then
        icon = icons.battery._25
        color = colors.orange
      else
        icon = icons.battery._0
        color = colors.red
      end
    end

    local lead = ""
    if found and charge < 10 then
      lead = "0"
    end

    battery:set({
      icon = {
        string = icon,
        color = color
      },
      label = { string = lead .. label },
    })
  end)
end)

battery:subscribe("mouse.clicked", function(env)
  local drawing = battery:query().popup.drawing
  battery:set( { popup = { drawing = "toggle" } })

  if drawing == "off" then
    sbar.exec("pmset -g batt", function(batt_info)
      local found, _, remaining = batt_info:find(" (%d+:%d+) remaining")
      local label = found and remaining .. "h" or "No estimate"
      remaining_time:set( { label = label })
    end)
  end
end)

sbar.add("bracket", "widgets.battery.bracket", { battery.name, tablet.name }, {
  background = { color = colors.bg1 }
})

sbar.add("item", "widgets.battery.padding", {
  position = "right",
  width = settings.group_paddings
})

update_tablet()
