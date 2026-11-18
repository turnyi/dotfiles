-- Migrated from ~/.tmux.conf (prefix ctrl+a).

-- ~/.tmux.conf:12
rex.bind("ctrl+a>ctrl+a", "pane.send_key", { key = "ctrl+a" })
-- ~/.tmux.conf:15
rex.bind("ctrl+a>\\", "pane.split", { direction = "right" })
-- ~/.tmux.conf:18
rex.bind("ctrl+a>-", "pane.split", { direction = "down" })
-- ~/.tmux.conf:21
rex.bind("ctrl+a>r", "client.config.reload")
-- tmux default prefix x (kill-pane)
rex.bind("ctrl+a>x", "pane.close")
-- tmux default prefix c (new-window); a tmux window is a Rex tab
rex.bind("ctrl+a>c", "client.tab.new")
-- Toolbar: show always -> on hover -> hidden. App settings can't be set from
-- this file, but a key can flip one; the app remembers the choice.
rex.bind("ctrl+a>t", "client.setting.interface.toolbar.auto_hide_toolbar")
-- prefix 0-9 selects a window like tmux; ~/.tmux.conf:188 sets base-index 0,
-- so 0 is the first tab (Rex counts tabs from 1)
for n = 0, 9 do
  rex.bind("ctrl+a>" .. n, "client.tab.goto", { index = n + 1 })
end

-- Repeatable bindings (bind -r): ctrl+a then ctrl+r enters repeat mode; enter or escape leaves.
rex.mode("repeat", { exclusive = true })
rex.bind("ctrl+a>ctrl+r", "client.mode.enter", { name = "repeat" })
rex.bind("repeat/enter", "client.mode.exit")
rex.bind("repeat/escape", "client.mode.exit")

-- ~/.tmux.conf:129
rex.bind("ctrl+a>j", "pane.resize", { amount = 5, direction = "down" })
rex.bind("repeat/j", "pane.resize", { amount = 5, direction = "down" })
-- ~/.tmux.conf:130
rex.bind("ctrl+a>k", "pane.resize", { amount = 5, direction = "up" })
rex.bind("repeat/k", "pane.resize", { amount = 5, direction = "up" })
-- ~/.tmux.conf:131
rex.bind("ctrl+a>l", "pane.resize", { amount = 5, direction = "right" })
rex.bind("repeat/l", "pane.resize", { amount = 5, direction = "right" })
-- ~/.tmux.conf:132
rex.bind("ctrl+a>h", "pane.resize", { amount = 5, direction = "left" })
rex.bind("repeat/h", "pane.resize", { amount = 5, direction = "left" })
-- ~/.tmux.conf:134
rex.bind("ctrl+a>m", "pane.zoom")
rex.bind("repeat/m", "pane.zoom")

-- Smart pane switching with awareness of vim splits, like vim-tmux-navigator
-- (~/.tmux.conf:193-196): in (n)vim the key goes through to vim, elsewhere it
-- moves focus to the neighbouring pane.
local terminal = "com.superlogical.terminal"

local function is_vim(block_id)
  local p = rex.block.call(terminal, "process", { block_id = block_id })
  local name = p and p.foreground and p.foreground.name
  if not name then return false end
  name = name:lower():match("[^/]*$")
  return name:match("^g?view$") ~= nil
    or name:match("^g?l?n?vim?x?$") ~= nil
    or name:match("^g?l?n?vim?x?diff$") ~= nil
end

for key, direction in pairs({ h = "left", j = "down", k = "up", l = "right" }) do
  rex.bind("ctrl+" .. key, function(ctx)
    if is_vim(ctx.block_id) then return false end
    rex.session.focus_direction{ direction = direction, wrap = true }
    return true
  end)
end

-- Remote hosts. `sshx HOST` (~/scripts/sshx) opens a session on one.
-- Full user@host: the Rex app has its own SSH client and reads no ~/.ssh/config.
-- This file is shared with turny itself, which shouldn't list itself as a host.
if rex.exec{ "hostname", "-s" }.stdout:gsub("%s+$", "") ~= "turny" then
  rex.host{ label = "turny", endpoint = "ssh://turny@turny.tail02a788.ts.net" }
end

-- kitty's look (kitty.conf:1244, macos.conf:20-24): slate #23252d over the
-- blurred desktop. Rex keeps appearance in the app's settings, not here, so
-- this action asks the app to apply it; run "Apply kitty Look" once from the
-- command palette (shift+cmd+p) on a new machine.
rex.action{
  name  = "apply_kitty_look",
  title = "Apply kitty Look",
  description = "Import the kitty-slate theme from dotfiles and turn on tinted glass panes.",
  run   = function(ctx, args)
    local theme = os.getenv("HOME") .. "/Projects/dotfiles/config/.config/rex/themes/kitty-slate"
    rex.client.queue("client.theme.import", { path = theme })
    rex.client.queue("client.setting.themes.dark.palette", { value = "kitty-slate" })
    rex.client.queue("client.setting.interface.appearance.style", { value = "glass" })
    rex.client.queue("client.setting.interface.appearance.glass", { value = true })
    rex.client.queue("client.setting.interface.appearance.tint", { value = true })
  end,
}

-- ctrl+shift+hjkl moves the pane, like moving windows in Hyprland/AeroSpace.
-- Rex's own pane.move only trades places with a pane that already lies that
-- way, so two stacked panes could never go side by side. When nothing lies
-- that way, re-split beside the nearest other pane instead.
local function leaves(node, out)
  if node.block_id then
    out[#out + 1] = { id = node.block_id, rect = node.rect }
  elseif node.split then
    leaves(node.split.before, out)
    leaves(node.split.after, out)
  end
  return out
end

local function window_leaves(block_id)
  local view = rex.session.view{}
  for _, w in ipairs(view and view.windows or {}) do
    for _, layer in ipairs(w.layers or {}) do
      if layer.kind == "tiled" and layer.layout then
        local all = leaves(layer.layout, {})
        for _, b in ipairs(all) do
          if b.id == block_id then return all, b end
        end
      end
    end
  end
end

local eps = 1e-6

local function overlaps(a0, a1, b0, b1)
  return math.min(a1, b1) - math.max(a0, b0) > eps
end

-- Whether b lies directly beside a in direction.
local function beside(a, b, direction)
  local ax, ay, aw, ah = a[1], a[2], a[3], a[4]
  local bx, by, bw, bh = b[1], b[2], b[3], b[4]
  if direction == "left" then
    return math.abs(bx + bw - ax) < eps and overlaps(ay, ay + ah, by, by + bh)
  elseif direction == "right" then
    return math.abs(ax + aw - bx) < eps and overlaps(ay, ay + ah, by, by + bh)
  elseif direction == "up" then
    return math.abs(by + bh - ay) < eps and overlaps(ax, ax + aw, bx, bx + bw)
  else
    return math.abs(ay + ah - by) < eps and overlaps(ax, ax + aw, bx, bx + bw)
  end
end

rex.action{
  name  = "pane_move_side",
  title = "Move Pane to Side",
  args  = { direction = "string" },
  run   = function(ctx, args)
    local d = args.direction
    local all, me = window_leaves(ctx.block_id)
    if not me or #all < 2 then return end
    for _, b in ipairs(all) do
      if b.id ~= me.id and beside(me.rect, b.rect, d) then
        rex.client.queue("pane.move", { direction = d })
        return
      end
    end
    -- Nothing that way: re-split beside a pane touching this one.
    local anchor
    for _, other in ipairs({ "up", "down", "left", "right" }) do
      for _, b in ipairs(all) do
        if not anchor and b.id ~= me.id and beside(me.rect, b.rect, other) then
          anchor = b
        end
      end
    end
    anchor = anchor or (all[1].id ~= me.id and all[1] or all[2])
    local _, err = rex.session.move_block{
      block_id = me.id,
      anchor_block_id = anchor.id,
      direction = (d == "left" or d == "right") and "horizontal" or "vertical",
      side = (d == "left" or d == "up") and "before" or "after",
    }
    if err ~= nil then error(err, 0) end
    rex.session.focus_block{ block_id = me.id }
  end,
}

-- Flip the focused pane and its neighbour between side by side and stacked,
-- like AeroSpace's alt-slash (layout tiles horizontal vertical). Rex can't
-- turn a split around, so the pane is re-split beside its neighbour.
local function parent_of(node, block_id)
  local sp = node.split
  if not sp then return end
  for _, side in ipairs({ "before", "after" }) do
    local child = sp[side]
    if child.block_id == block_id then
      return sp, side, sp[side == "before" and "after" or "before"]
    end
    local a, b, c = parent_of(child, block_id)
    if a then return a, b, c end
  end
end

local function first_leaf(node)
  while node.split do node = node.split.before end
  return node.block_id
end

rex.action{
  name  = "pane_toggle_split",
  title = "Toggle Split Direction",
  run   = function(ctx, args)
    local view = rex.session.view{}
    for _, w in ipairs(view and view.windows or {}) do
      for _, layer in ipairs(w.layers or {}) do
        if layer.kind == "tiled" and layer.layout then
          local sp, side, sibling = parent_of(layer.layout, ctx.block_id)
          if sp then
            local _, err = rex.session.move_block{
              block_id = ctx.block_id,
              anchor_block_id = sibling.block_id or first_leaf(sibling),
              direction = sp.direction == "vertical" and "horizontal" or "vertical",
              side = side,
            }
            if err ~= nil then error(err, 0) end
            rex.session.focus_block{ block_id = ctx.block_id }
            return
          end
        end
      end
    end
  end,
}

-- AeroSpace-style layout keys behind the prefix (alt itself belongs to AeroSpace)
rex.bind("ctrl+a>/", "pane_toggle_split")   -- alt-slash: tiles horizontal/vertical
rex.bind("ctrl+a>=", "pane.balance")        -- service mode b: balance-sizes

-- prefix v, as ~/.tmux.conf:103: paste the server's desktop clipboard (the one
-- ClipCascade syncs with the Mac) into the pane. clip-paste.sh runs on the
-- host over ssh and prints an image's saved path or the text; Rex then types
-- it into the pane. In a local pane it is the ordinary paste.
local function bracketed_paste(block_id)
  local m = rex.block.call(terminal, "modes", { block_id = block_id })
  for _, mode in ipairs(m and m.modes or {}) do
    if mode.number == 2004 then return mode.set end
  end
  return false
end

rex.action{
  name  = "clip_paste",
  title = "Paste Server Clipboard",
  description = "Paste the host's ClipCascade clipboard: an image is saved to ~/.shots and its path typed.",
  args  = { host = "string?" },
  run   = function(ctx, args)
    local host = args.host or ctx.server
    if not host then
      rex.client.queue("pane.paste")
      return
    end
    local r, err = rex.exec(
      { "ssh", "-o", "BatchMode=yes", "-o", "ConnectTimeout=5", host, "~/scripts/clip-paste.sh" },
      { timeout = 20 })
    if r == nil then error(err, 0) end
    if not r.ok then error((r.stderr:gsub("%s+$", "")), 0) end
    local data = r.stdout
    local image = data:match("^(/[^\n]*/clip%-%d+%-%d+%.png)\n?$")
    if image then
      data = image .. " "
    elseif bracketed_paste(ctx.block_id) then
      data = "\27[200~" .. data .. "\27[201~"
    end
    local _, werr = rex.block.call(terminal, "write", { block_id = ctx.block_id, data = data })
    if werr ~= nil then error(werr, 0) end
  end,
}
rex.bind("ctrl+a>v", "clip_paste")

rex.bind("ctrl+shift+h", "pane_move_side", { direction = "left" })
rex.bind("ctrl+shift+j", "pane_move_side", { direction = "down" })
rex.bind("ctrl+shift+k", "pane_move_side", { direction = "up" })
rex.bind("ctrl+shift+l", "pane_move_side", { direction = "right" })
