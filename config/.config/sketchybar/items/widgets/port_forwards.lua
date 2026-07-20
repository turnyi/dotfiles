local colors = require("colors")
local settings = require("settings")

local HOME = os.getenv("HOME")
local PF = HOME .. "/scripts/pf-ctl.sh"

-- Glyphs by codepoint so the raw PUA bytes never live in this file (and can't be
-- stripped by an editor that doesn't grok nerdfont).
local TUNNEL  = utf8.char(0xf0ec) -- exchange / tunnel
local DOT_ON  = utf8.char(0xf111) -- filled circle
local DOT_OFF = utf8.char(0xf10c) -- hollow circle
local STOP    = utf8.char(0xf04d) -- stop square

-- Padding item required because of the bracket
sbar.add("item", { position = "right", width = settings.group_paddings })

local pf = sbar.add("item", "widgets.pf", {
  position = "right",
  icon = {
    string = TUNNEL,
    font = { family = settings.font.text, size = 14.0 },
    color = colors.grey,
    padding_left = 8,
    padding_right = 4,
  },
  label = {
    string = "",
    font = { family = settings.font.numbers, size = 12.0 },
    color = colors.green,
    padding_right = 8,
    drawing = false,
  },
  popup = { align = "center" },
})

-- Custom event pf-ctl.sh triggers after it changes a tunnel; register it before
-- anything subscribes.
sbar.add("event", "pf_update")

local built = false          -- built the static popup chrome yet?
local slot_rows = {}          -- name -> item in its project section

local POPUP = "popup.widgets.pf"

local function add_header(key, text)
  return sbar.add("item", "pf.hdr." .. key, {
    position = POPUP,
    icon = { drawing = false },
    label = {
      string = text,
      color = colors.grey,
      font = { family = settings.font.text, style = "Bold", size = 11.0 },
      padding_left = 8, padding_right = 12, align = "left", width = 210,
    },
    background = { drawing = false },
  })
end

local function add_row(item_name, width)
  return sbar.add("item", item_name, {
    position = POPUP,
    icon = {
      font = { family = settings.font.text, size = 13.0 },
      padding_left = 20, padding_right = 8, align = "left",
    },
    label = {
      font = { family = settings.font.text, size = 13.0 },
      padding_right = 14, align = "left", width = width,
    },
  })
end

local function detailed(label, detail)
  if detail ~= nil and detail ~= "" then
    return label .. "   " .. detail
  end
  return label
end

local function refresh()
  sbar.exec(PF .. " list", function(out)
    -- Parse: name|group|label|detail|status
    local entries = {}
    local groups, seen = {}, {}
    for line in out:gmatch("[^\r\n]+") do
      local name, group, label, detail, status =
        line:match("([^|]*)|([^|]*)|([^|]*)|([^|]*)|([^|]*)")
      if name and name ~= "" then
        entries[#entries + 1] =
          { name = name, group = group, label = label, detail = detail, on = (status == "on") }
        if not seen[group] then
          seen[group] = true
          groups[#groups + 1] = group
        end
      end
    end

    -- Build the popup once, in display order: one section per project, then the
    -- Stop-all footer.
    if not built then
      built = true

      for _, g in ipairs(groups) do
        add_header("grp." .. g, g)
        for _, e in ipairs(entries) do
          if e.group == g then
            local r = add_row("pf.row." .. e.name, 150)
            r:subscribe("mouse.clicked", function()
              sbar.exec(PF .. " toggle " .. e.name, refresh)
            end)
            slot_rows[e.name] = r
          end
        end
      end

      local stop = sbar.add("item", "pf.stopall", {
        position = POPUP,
        icon = {
          string = STOP, color = colors.red,
          font = { family = settings.font.text, size = 13.0 },
          padding_left = 8, padding_right = 8, align = "left",
        },
        label = {
          string = "Stop all", color = colors.red,
          font = { family = settings.font.text, size = 13.0 },
          padding_right = 14, align = "left", width = 220,
        },
      })
      stop:subscribe("mouse.clicked", function()
        sbar.exec(PF .. " stop-all", refresh)
      end)
    end

    -- Update every row's live state.
    local running = 0
    for _, e in ipairs(entries) do
      if e.on then running = running + 1 end

      local sr = slot_rows[e.name]
      if sr then
        sr:set({
          icon = { string = e.on and DOT_ON or DOT_OFF, color = e.on and colors.green or colors.grey },
          label = { string = detailed(e.label, e.detail), color = e.on and colors.white or colors.grey },
        })
      end
    end

    -- Main bar item reflects how many tunnels are up.
    pf:set({
      icon = { color = running > 0 and colors.green or colors.grey },
      label = { drawing = running > 0, string = tostring(running) },
    })
  end)
end

pf:subscribe("mouse.clicked", function()
  pf:set({ popup = { drawing = "toggle" } })
  refresh()
end)

-- Keep status fresh: periodic routine + a custom event pf-ctl.sh triggers.
pf:subscribe({ "forced", "routine" }, refresh)
pf:subscribe("pf_update", refresh)

sbar.add("bracket", "widgets.pf.bracket", { pf.name }, {
  background = { color = colors.bg1 },
})

sbar.add("item", "widgets.pf.padding", {
  position = "right",
  width = settings.group_paddings,
})

pf:set({ update_freq = 15 })
refresh()
