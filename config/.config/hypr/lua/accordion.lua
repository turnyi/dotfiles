local M = {}

local DEFAULTS = {
  -- place() subtracts gaps_in on each edge, so 22 requested = 12px visible.
  sliver = 22,
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

local function even_split(list, a)
  local w = a.w / #list
  for i = 1, #list do
    list[i]:place({ x = a.x + w * (i - 1), y = a.y, w = w, h = a.h })
  end
end

local function recalculate(ctx)
  local a = ctx.area
  local list = {}
  for _, t in ipairs(ctx.targets) do list[#list + 1] = t end
  local n = #list
  if n == 0 then return end
  if n == 1 then
    list[1]:place({ x = a.x, y = a.y, w = a.w, h = a.h })
    return
  end
  table.sort(list, by_rank)

  local ws = workspace_id(list)
  local active = hl.get_active_window()
  local focus = index_of(list, active and active.address)
  if focus then
    expanded[ws] = active.address
  else
    focus = index_of(list, expanded[ws]) or 1
  end

  local sliver = opts.sliver
  local big = a.w - sliver * (n - 1)
  if big <= sliver then
    even_split(list, a)
    return
  end

  local cx = a.x
  for i = 1, n do
    local tw = (i == focus) and big or sliver
    list[i]:place({ x = cx, y = a.y, w = tw, h = a.h })
    cx = cx + tw
  end
end

local function layout_msg(ctx, msg)
  if msg == "refocus" then return true end
  if msg ~= "moveleft" and msg ~= "moveright" then return nil end
  local active = hl.get_active_window()
  if not active then return true end
  local list = {}
  for _, t in ipairs(ctx.targets) do list[#list + 1] = t end
  table.sort(list, by_rank)
  local at = index_of(list, active.address)
  if not at then return true end
  local swap = (msg == "moveleft") and (at - 1) or (at + 1)
  if swap < 1 or swap > #list then return true end
  local other = list[swap].window.address
  rank[active.address], rank[other] = rank[other], rank[active.address]
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
      hl.dispatch(hl.dsp.layout("refocus"))
    end
  end)
end

return M
