local colors = require("colors")
local settings = require("settings")

local HOME = os.getenv("HOME")
local COUNT_SCRIPT = HOME .. "/scripts/notif-count.sh"
local OPEN_SCRIPT = HOME .. "/scripts/notif-open.sh"

local BELL = "" -- nerdfont bell

-- Padding item required because of the bracket
sbar.add("item", { position = "right", width = settings.group_paddings })

local notif = sbar.add("item", "widgets.notifications", {
  position = "right",
  icon = {
    string = BELL,
    font = { family = settings.font.text, size = 15.0 },
    color = colors.grey,
    padding_left = 8,
    padding_right = 4,
  },
  label = {
    string = "0",
    font = { family = settings.font.numbers, size = 12.0 },
    color = colors.white,
    padding_right = 8,
  },
  update_freq = 10,
})

local function render(out)
  local count, token = out:match("^(%d+)|(.*)")
  count = tonumber(count) or 0

  if count == 0 then
    -- Nothing pending: dim bell, no number, plain text font.
    notif:set({
      icon = { string = BELL, color = colors.grey, font = { family = settings.font.text, size = 15.0 } },
      label = { drawing = false },
    })
    return
  end

  token = (token ~= nil and token:gsub("%s+$", "")) or ""
  if token ~= "" and token ~= ":default:" then
    -- Show the notifying app's glyph via the sketchybar-app-font.
    notif:set({
      icon = { string = token, color = colors.white, font = "sketchybar-app-font:Regular:15.0" },
      label = { drawing = true, string = tostring(count), color = colors.red },
    })
  else
    -- Unknown app: fall back to a red bell + count.
    notif:set({
      icon = { string = BELL, color = colors.red, font = { family = settings.font.text, size = 15.0 } },
      label = { drawing = true, string = tostring(count), color = colors.red },
    })
  end
end

local function update()
  sbar.exec(COUNT_SCRIPT, render)
end

notif:subscribe({ "forced", "routine", "system_woke" }, update)

notif:subscribe("mouse.clicked", function()
  sbar.exec(OPEN_SCRIPT)
  -- Give NC a moment to settle, then refresh the count.
  sbar.exec("sleep 1", update)
end)

sbar.add("bracket", "widgets.notifications.bracket", { notif.name }, {
  background = { color = colors.bg1 },
})

sbar.add("item", "widgets.notifications.padding", {
  position = "right",
  width = settings.group_paddings,
})

update()
