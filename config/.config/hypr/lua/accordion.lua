local M = {}

local DEFAULTS = {
  step = 40,
}

local opts = setmetatable({}, { __index = DEFAULTS })

local rank = {}
local next_rank = 0
local expanded = {}

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

local function workspace_id(targets)
  for i = 1, #targets do
    local w = targets[i].window
    if w and w.workspace then return w.workspace.id end
  end
  return 0
end

local function index_of(list, addr)
  if not addr then return nil end
  for i = 1, #list do
    local w = list[i].window
    if w and w.address == addr then return i end
  end
  return nil
end

local function sorted_targets(ctx)
  local list = {}
  for _, t in ipairs(ctx.targets) do list[#list + 1] = t end
  table.sort(list, by_rank)
  return list
end

local function even_split(list, a)
  local w = a.w / #list
  for i = 1, #list do
    list[i]:place({ x = a.x + w * (i - 1), y = a.y, w = w, h = a.h })
  end
end

local function focused_index(list)
  local ws = workspace_id(list)
  local active = hl.get_active_window()
  local focus = index_of(list, active and active.address)
  if focus then
    expanded[ws] = active.address
    return focus
  end
  return index_of(list, expanded[ws]) or 1
end

-- The focused window sits at the front of the deck (largest offset, drawn
-- last by the compositor); the rest keep their rank order behind it so each
-- one's top-left corner stays visible as a step.
local function recalculate(ctx)
  local a = ctx.area
  local list = sorted_targets(ctx)
  local n = #list
  if n == 0 then return end
  if n == 1 then
    list[1]:place({ x = a.x, y = a.y, w = a.w, h = a.h })
    return
  end

  local focus = focused_index(list)
  local step = opts.step
  local inset = step * (n - 1)
  if inset * 2 > a.w or inset * 2 > a.h then
    even_split(list, a)
    return
  end

  local deck = {}
  for i = 1, n do
    if i ~= focus then deck[#deck + 1] = list[i] end
  end
  deck[#deck + 1] = list[focus]

  for i = 1, n do
    local off = step * (i - 1)
    deck[i]:place({ x = a.x + off, y = a.y + off, w = a.w - inset, h = a.h - inset })
  end
end

local function neighbour(ctx, delta)
  local active = hl.get_active_window()
  if not active then return nil, nil end
  local list = sorted_targets(ctx)
  local at = index_of(list, active.address)
  if not at then return nil, nil end
  local other = at + delta
  if other < 1 or other > #list then return nil, nil end
  return active, list[other].window
end

local function layout_msg(ctx, msg)
  if msg == "refocus" then return true end
  if msg == "focusprev" or msg == "focusnext" then
    local _, target = neighbour(ctx, msg == "focusprev" and -1 or 1)
    if target then hl.dispatch(hl.dsp.focus({ window = "address:" .. target.address })) end
    return true
  end
  if msg ~= "moveleft" and msg ~= "moveright" then return nil end
  local active, other = neighbour(ctx, msg == "moveleft" and -1 or 1)
  if other then
    rank[active.address], rank[other.address] = rank[other.address], rank[active.address]
  end
  return true
end

function M.setup(user_opts)
  for k, v in pairs(user_opts or {}) do opts[k] = v end
  hl.layout.register("accordion", {
    recalculate = recalculate,
    layout_msg = layout_msg,
  })
  hl.on("window.active", function()
    local ws = hl.get_active_workspace()
    if ws and ws.tiled_layout == "lua:accordion" then
      hl.dispatch(hl.dsp.window.alter_zorder({ mode = "top" }))
      hl.dispatch(hl.dsp.layout("refocus"))
    end
  end)
end

return M
