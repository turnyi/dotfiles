local colors = require("colors")
local settings = require("settings")

local NOW_PLAYING = os.getenv("HOME") .. "/scripts/now-playing.sh 40"

local MUSIC = utf8.char(0xf075a)

local media = sbar.add("item", "widgets.media", {
  position = "right",
  drawing = false,
  icon = {
    string = MUSIC,
    font = { family = settings.font.text, size = 15.0 },
    color = colors.magenta,
    padding_left = 8,
    padding_right = 4,
  },
  label = {
    font = { family = settings.font.text, size = 12.0 },
    color = colors.white,
    padding_right = 8,
  },
  update_freq = 3,
})

local bracket = sbar.add("bracket", "widgets.media.bracket", { media.name }, {
  drawing = false,
  background = { color = colors.bg1 },
})

local padding = sbar.add("item", "widgets.media.padding", {
  position = "right",
  drawing = false,
  width = settings.group_paddings,
})

local function render(out)
  local track = (out or ""):gsub("%s+$", "")
  local playing = track ~= ""
  media:set({ drawing = playing, label = { string = track } })
  bracket:set({ drawing = playing })
  padding:set({ drawing = playing })
end

local function update()
  sbar.exec(NOW_PLAYING, render)
end

media:subscribe({ "forced", "routine", "system_woke" }, update)

media:subscribe("mouse.clicked", function()
  sbar.exec("media-control toggle-play-pause", update)
end)

update()
