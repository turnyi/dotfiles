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

local function even_split(list, x, y, w, h)
  local n = #list
  local each = h / n
  for i = 1, n do
    list[i]:place({ x = x, y = y + (i - 1) * each, w = w, h = each })
  end
end

local function place_side(list, x, y, w, h, ws, side, active_addr)
  local n = #list
  if n == 0 then return end
  if n == 1 then
    list[1]:place({ x = x, y = y, w = w, h = h })
    return
  end

  if not accordion[ws] then
    even_split(list, x, y, w, h)
    return
  end

  local key = ws .. ":" .. side
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

  if n == 1 then
    targets[1]:place(a)
    return
  end

  local ws = workspace_id(targets)
  local active = hl.get_active_window()
  local active_addr = active and active.address or nil

  for i = #left, 1, -1 do left[i] = nil end
  for i = #right, 1, -1 do right[i] = nil end

  for i = 2, n do
    if i % 2 == 0 then
      right[#right + 1] = targets[i]
    else
      left[#left + 1] = targets[i]
    end
  end

  local mw = a.w * mfact
  local side = (a.w - mw) / 2

  -- One column empty (n == 2): give master that half rather than centring it
  -- against dead space.
  if #left == 0 then
    targets[1]:place({ x = a.x, y = a.y, w = a.w - side, h = a.h })
    place_side(right, a.x + a.w - side, a.y, side, a.h, ws, "r", active_addr)
    return
  end
  if #right == 0 then
    place_side(left, a.x, a.y, side, a.h, ws, "l", active_addr)
    targets[1]:place({ x = a.x + side, y = a.y, w = a.w - side, h = a.h })
    return
  end

  targets[1]:place({ x = a.x + side, y = a.y, w = mw, h = a.h })
  place_side(left, a.x, a.y, side, a.h, ws, "l", active_addr)
  place_side(right, a.x + side + mw, a.y, side, a.h, ws, "r", active_addr)
end

local function layout_msg(ctx, msg)
  if msg == "toggleaccordion" then
    local ws = workspace_id(ctx.targets)
    accordion[ws] = not accordion[ws]
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
