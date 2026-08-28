local M = {}

local DEFAULTS = {
  mfact = 0.5,
  mfact_min = 0.2,
  mfact_max = 0.8,
  mfact_step = 0.05,
  sliver_min = 24,
  sliver_budget = 100,
  sliver_max = 80,
}

local opts = setmetatable({}, { __index = DEFAULTS })

local mfact = DEFAULTS.mfact
local accordion = {}
local expanded = {}

local left, right = {}, {}

local function workspace_id(targets)
  for i = 1, #targets do
    local w = targets[i].window
    if w and w.workspace then return w.workspace.id end
  end
  return 0
end

local function sliver_for(n)
  local s = opts.sliver_budget / n
  if s < opts.sliver_min then s = opts.sliver_min end
  if s > opts.sliver_max then s = opts.sliver_max end
  return s
end

-- Stacked mode splits like dwindle rather than stacking everything top to
-- bottom: cut across, then down the halves, alternating each level. Each cut is
-- an even half of the box it divides, so opening a window never leaves the new
-- split taller than the one it was carved out of.
local function bsp(list, lo, hi, x, y, w, h, cut_across)
  local n = hi - lo + 1
  if n < 1 then return end
  if n == 1 then
    list[lo]:place({ x = x, y = y, w = w, h = h })
    return
  end
  local half = n // 2
  if cut_across then
    local top = h / 2
    bsp(list, lo, lo + half - 1, x, y, w, top, false)
    bsp(list, lo + half, hi, x, y + top, w, h - top, false)
  else
    local left = w / 2
    bsp(list, lo, lo + half - 1, x, y, left, h, true)
    bsp(list, lo + half, hi, x + left, y, w - left, h, true)
  end
end

local function even_split(list, x, y, w, h)
  bsp(list, 1, #list, x, y, w, h, true)
end

-- A window's column is decided once, when it first appears, and remembered
-- against its address for as long as it lives. Nothing is ever rebalanced, so
-- five windows on one side and one on the other is a state you can hold; the
-- alternative moves a window you were not touching every time you open one.
local side_memo = {}
local last_side = "r"

local function active_address()
  local a = hl.get_active_window()
  return a and a.address or nil
end

local function place_side(list, x, y, w, h, ws, side, active_addr)
  local n = #list
  if n == 0 then return end
  if n == 1 then
    list[1]:place({ x = x, y = y, w = w, h = h })
    return
  end

  local key = ws .. ":" .. side
  if not accordion[key] then
    even_split(list, x, y, w, h)
    return
  end

  local focus

  if active_addr then
    for i = 1, n do
      local win = list[i].window
      if win and win.address == active_addr then
        focus = i
        expanded[key] = active_addr
        break
      end
    end
  end

  -- No window here is focused: stay on the one this column last expanded, so
  -- focusing the other column does not silently reshuffle this one.
  if not focus then
    local remembered = expanded[key]
    if remembered then
      for i = 1, n do
        local win = list[i].window
        if win and win.address == remembered then
          focus = i
          break
        end
      end
    end
  end
  focus = focus or 1

  local sliver = sliver_for(n)
  local big = h - sliver * (n - 1)
  -- Too many windows for the expanded one to stay larger than a sliver; an even
  -- split is the only thing left that does not produce negative heights.
  if big <= sliver then
    even_split(list, x, y, w, h)
    return
  end

  local cy = y
  for i = 1, n do
    local th = (i == focus) and big or sliver
    list[i]:place({ x = x, y = cy, w = w, h = th })
    cy = cy + th
  end
end

local function recalculate(ctx)
  local a = ctx.area
  local targets = ctx.targets
  local n = #targets
  if n == 0 then return end

  local mw = a.w * mfact
  local side = (a.w - mw) / 2

  -- A lone window keeps the master's width rather than filling the screen, so
  -- the master column does not resize as windows come and go.
  if n == 1 then
    targets[1]:place({ x = a.x + side, y = a.y, w = mw, h = a.h })
    return
  end

  local ws = workspace_id(targets)
  local active = hl.get_active_window()
  local active_addr = active and active.address or nil

  for i = #left, 1, -1 do left[i] = nil end
  for i = #right, 1, -1 do right[i] = nil end

  -- New windows follow the column you are focused in, falling back to whichever
  -- column the last one went to. They never balance and never move afterwards,
  -- so a run of new windows stacks up on one side and five-against-one is a
  -- state you can sit in. SUPER+SHIFT+[ / ] moves one across.
  local focus_side = active_addr and side_memo[active_addr] or nil

  for i = 2, n do
    local w = targets[i].window
    local addr = w and w.address
    local s = addr and side_memo[addr]
    if not s then
      s = focus_side or last_side
      last_side = s
      if addr then side_memo[addr] = s end
    end
    if s == "l" then
      left[#left + 1] = targets[i]
    else
      right[#right + 1] = targets[i]
    end
  end

  -- An empty column is left as dead space rather than absorbed: the master is
  -- meant to hold the same width whatever else is open.
  targets[1]:place({ x = a.x + side, y = a.y, w = mw, h = a.h })
  place_side(left, a.x, a.y, side, a.h, ws, "l", active_addr)
  place_side(right, a.x + side + mw, a.y, side, a.h, ws, "r", active_addr)
end

-- Which column holds the focused window, so a bare toggle acts on the side you
-- are looking at. nil when focus is on the master or on nothing.
local function active_side()
  local addr = active_address()
  return addr and side_memo[addr] or nil
end

local function toggle(ws, side)
  local key = ws .. ":" .. side
  accordion[key] = not accordion[key]
end

local function layout_msg(ctx, msg)
  if msg == "toggleaccordion" then
    local ws = workspace_id(ctx.targets)
    local side = active_side()
    if side then
      toggle(ws, side)
    else
      toggle(ws, "l")
      toggle(ws, "r")
    end
    return true
  elseif msg == "toggleaccordionleft" then
    toggle(workspace_id(ctx.targets), "l")
    return true
  elseif msg == "toggleaccordionright" then
    toggle(workspace_id(ctx.targets), "r")
    return true
  elseif msg == "toggleaccordionboth" then
    local ws = workspace_id(ctx.targets)
    toggle(ws, "l")
    toggle(ws, "r")
    return true
  elseif msg == "sendleft" or msg == "sendright" or msg == "sendotherside" then
    local addr = active_address()
    if not addr then return true end
    if msg == "sendleft" then
      side_memo[addr] = "l"
    elseif msg == "sendright" then
      side_memo[addr] = "r"
    else
      side_memo[addr] = (side_memo[addr] == "l") and "r" or "l"
    end
    return true
  elseif msg == "mfact+" then
    mfact = math.min(mfact + opts.mfact_step, opts.mfact_max)
    return true
  elseif msg == "mfact-" then
    mfact = math.max(mfact - opts.mfact_step, opts.mfact_min)
    return true
  end
  return nil
end

function M.setup(user_opts)
  for k, v in pairs(user_opts or {}) do opts[k] = v end
  mfact = opts.mfact
  hl.layout.register("centermaster", {
    recalculate = recalculate,
    layout_msg = layout_msg,
  })
end

return M
