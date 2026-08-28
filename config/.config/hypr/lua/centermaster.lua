local M = {}

local DEFAULTS = {
  mfact = 0.5,
  mfact_min = 0.2,
  mfact_max = 0.8,
  mfact_step = 0.05,
  -- place() subtracts gaps_in on each edge, so a slot renders about 10px
  -- shorter than it is asked for; these are sized for the visible result.
  sliver_min = 40,
  sliver_budget = 180,
  sliver_max = 96,
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
-- Hyprland's movewindow dispatcher has no hook in the lua layout API, so which
-- window is master and the order within a column are ours to track. rank orders
-- windows; master_memo pins one per workspace.
local rank = {}
local master_memo = {}
local next_rank = 0

local function rank_of(addr)
  if not rank[addr] then
    next_rank = next_rank + 1
    rank[addr] = next_rank
  end
  return rank[addr]
end

local function by_rank(a, b)
  local wa, wb = a.window, b.window
  if not wa then return false end
  if not wb then return true end
  return rank_of(wa.address) < rank_of(wb.address)
end

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

  -- Master is whichever window was last promoted here, falling back to the
  -- oldest one when that window is gone.
  local pinned = master_memo[ws]
  local master_i
  for i = 1, n do
    local w = targets[i].window
    if w then
      rank_of(w.address)
      if pinned and w.address == pinned then master_i = i end
    end
  end
  if not master_i then
    master_i = 1
    for i = 2, n do
      if by_rank(targets[i], targets[master_i]) then master_i = i end
    end
  end

  -- Where a new window goes depends on what you are focused on: inside a column
  -- it joins that column, so a run of new windows stacks up beside the one you
  -- are working in. From the master there is no such hint, so it goes to
  -- whichever column is emptier rather than leaving one side blank.
  -- Either way the choice is remembered against the window's address and never
  -- revisited, so opening a window never shuffles one that is already placed.
  -- SUPER+SHIFT+[ / ] moves one across.
  local nl, nr = 0, 0
  for i = 1, n do
    if i ~= master_i then
      local w = targets[i].window
      local s = w and side_memo[w.address]
      if s == "l" then
        nl = nl + 1
      elseif s == "r" then
        nr = nr + 1
      end
    end
  end

  local focus_side = active_addr and side_memo[active_addr] or nil

  -- Balancing is off once either column of this workspace is an accordion:
  -- dropping a window into one reshuffles every sliver in it. New windows go to
  -- the column you are focused in, else to the side that is still stacked.
  local acc_l = accordion[ws .. ":l"]
  local acc_r = accordion[ws .. ":r"]
  local function home_for_new()
    if focus_side then return focus_side end
    if acc_l and not acc_r then return "r" end
    if acc_r and not acc_l then return "l" end
    if acc_l and acc_r then return "r" end
    return (nl <= nr) and "l" or "r"
  end

  for i = 1, n do
    if i ~= master_i then
      local w = targets[i].window
      local addr = w and w.address
      local s = addr and side_memo[addr]
      if not s then
        s = home_for_new()
        if s == "l" then nl = nl + 1 else nr = nr + 1 end
        if addr then side_memo[addr] = s end
      end
      if s == "l" then
        left[#left + 1] = targets[i]
      else
        right[#right + 1] = targets[i]
      end
    end
  end

  table.sort(left, by_rank)
  table.sort(right, by_rank)

  -- An empty column is left as dead space rather than absorbed: the master is
  -- meant to hold the same width whatever else is open.
  targets[master_i]:place({ x = a.x + side, y = a.y, w = mw, h = a.h })
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
  elseif msg == "swapmaster" then
    -- Promote the focused window; the window it displaces takes over its column
    -- slot so nothing is left without a home.
    local addr = active_address()
    if not addr then return true end
    local ws = workspace_id(ctx.targets)
    local old_master = master_memo[ws]
    if not old_master then
      for _, t in ipairs(ctx.targets) do
        local w = t.window
        if w and not side_memo[w.address] then old_master = w.address break end
      end
    end
    if old_master == addr then return true end
    if old_master then
      side_memo[old_master] = side_memo[addr] or "l"
    end
    side_memo[addr] = nil
    master_memo[ws] = addr
    return true
  elseif msg == "moveup" or msg == "movedown" then
    -- Reorder within a column by swapping ranks with the neighbour above or
    -- below; the master has no column to move inside.
    local addr = active_address()
    local side = addr and side_memo[addr]
    if not side then return true end
    local col = {}
    for _, t in ipairs(ctx.targets) do
      local w = t.window
      if w and side_memo[w.address] == side then col[#col + 1] = w.address end
    end
    table.sort(col, function(x, y) return rank_of(x) < rank_of(y) end)
    local at
    for i, x in ipairs(col) do if x == addr then at = i break end end
    if not at then return true end
    local swap = (msg == "moveup") and (at - 1) or (at + 1)
    if swap < 1 or swap > #col then return true end
    local other = col[swap]
    rank[addr], rank[other] = rank[other], rank[addr]
    return true
  elseif msg == "refocus" then
    -- No state change; dispatched on focus so the compositor re-runs
    -- recalculate and the accordion can follow the newly focused window.
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
  -- Focus alone does not make the compositor re-run the layout, so an accordion
  -- column would keep whichever window was expanded when it was last laid out.
  hl.on("window.active", function()
    hl.dispatch(hl.dsp.layout("refocus"))
  end)
end

return M
