local settings = require("settings")
local colors = require("colors")

local NEXT_EVENT = "~/.config/sketchybar/plugins/next_event.sh"

-- How often to ask the calendar, in routine ticks. The clock ticks every 30s;
-- icalBuddy is heavy enough that polling it that often would be wasteful, and
-- an event that is minutes away does not need second-level precision.
local EVENT_EVERY_N_TICKS = 4 -- ~2 minutes
local SOON_MIN = 15           -- within this, the event is "imminent"
local MAX_TITLE = 22

-- Padding item required because of bracket
sbar.add("item", { position = "right", width = settings.group_paddings })

local cal = sbar.add("item", {
  icon = {
    color = colors.white,
    padding_left = 8,
    font = {
      style = settings.font.style_map["Black"],
      size = 12.0,
    },
  },
  label = {
    color = colors.white,
    -- The clock is the constant and the date/event is what varies beside it,
    -- so it needs a real gap or "Design review 18:01" reads as one string.
    padding_left = 12,
    padding_right = 8,
    width = 49,
    align = "right",
    font = { family = settings.font.numbers },
  },
  position = "right",
  update_freq = 30,
  padding_left = 1,
  padding_right = 1,
  background = {
    color = colors.bg1,
    border_color = colors.bg2,
    border_width = 1,
  },
  click_script = "open -a 'Calendar'"
})

sbar.add("bracket", { cal.name }, {
  background = {
    color = colors.transparent,
    height = 28,
    corner_radius = 12,
    border_width = 0,
    border_color = colors.transparent,
  },
  blur_radius = 60,
})

-- Padding item required because of bracket
sbar.add("item", { position = "right", width = settings.group_paddings })

local tick = 0
local current_event = nil -- { mins, time, title } or nil

local function render()
  -- The date is the fallback, not the point: when something is actually
  -- coming up, that is the more useful thing to occupy the slot.
  if current_event then
    local title = current_event.title
    if #title > MAX_TITLE then
      title = title:sub(1, MAX_TITLE - 1) .. "…"
    end

    local text, color
    if current_event.mins < 0 then
      text = "now · " .. title
      color = colors.active
    elseif current_event.mins <= SOON_MIN then
      text = current_event.mins .. "m · " .. title
      color = colors.active
    else
      text = current_event.time .. " · " .. title
      color = colors.white
    end

    cal:set({ icon = { string = text, color = color } })
  else
    cal:set({ icon = { string = os.date("%a. %d %b."), color = colors.white } })
  end

  cal:set({ label = os.date("%H:%M") })
end

local function refresh_event()
  sbar.exec(NEXT_EVENT, function(result)
    local line = (result or ""):match("^[^\n]*") or ""
    local mins, time, title = line:match("^(-?%d+)|(%d%d:%d%d)|(.+)$")
    if mins then
      current_event = { mins = tonumber(mins), time = time, title = title }
    else
      current_event = nil
    end
    render()
  end)
end

cal:subscribe({ "forced", "routine", "system_woke" }, function(env)
  render()
  if tick % EVENT_EVERY_N_TICKS == 0 or env.SENDER == "system_woke" then
    refresh_event()
  end
  tick = tick + 1
end)

-- Clicking through to Calendar usually means something changed; re-check on
-- the way back rather than waiting out the poll interval.
cal:subscribe("mouse.clicked", function()
  refresh_event()
end)

refresh_event()
