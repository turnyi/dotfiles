---@class VimModeGradient
---@field colors string[]
---@field angle integer

---@class VimModeOpts
---@field skip string[]
---@field border VimModeGradient

local VimMode = {}

local HYPRVIM = os.getenv("HOME") .. "/.local/share/hyprland/lua/plugins/hyprvim/init.lua"

local MODE_BORDERS = {
  NORMAL     = "rgba(9ed072ee)",
  VISUAL     = "rgba(f39660ee)",
  ["V-LINE"] = "rgba(f39660ee)",
}
local PENDING_BORDER = "rgba(e7c664ee)"

local SUPER_KEYS = { [133] = true, [134] = true }
local DOUBLE_ESCAPE_MS = 150

---@param path string
---@return boolean
local function exists(path)
  local file = io.open(path)
  if not file then return false end
  file:close()
  return true
end

---@param pid integer|nil
---@return string|nil
local function processName(pid)
  if not pid then return nil end
  local file = io.open("/proc/" .. pid .. "/comm")
  if not file then return nil end
  local name = file:read("l")
  file:close()
  return name
end

-- set_prop's gradient parser drops the first color when an angle follows (0.56.2), and "unset" leaves an
-- empty override that hides the border, so idle windows get the global gradient back with a throwaway lead color.
---@param gradient VimModeGradient
---@return string
local function gradientProp(gradient)
  return "rgba(00000000) " .. table.concat(gradient.colors, " ") .. " " .. gradient.angle .. "deg"
end

---@return boolean
local function overlayFocused()
  for _, layer in ipairs(hl.get_layers()) do
    if layer.mapped and layer.interactivity ~= 0 then return true end
  end
  return false
end

---@param name string|nil
---@return boolean
local function isIdle(name)
  return name == nil or name == "" or name == "reset" or name == "INSERT"
end

---@param opts VimModeOpts
function VimMode.setup(opts)
  if not exists(HYPRVIM) then return end

  local function cycleSection(mods)
    return function() require("hyprvim.hypr").send(mods, "F6") end
  end

  dofile(HYPRVIM).setup({
    keys      = { activate = "ESCAPE" },
    which_key = { enabled = false },
  })

  hl.define_submap("NORMAL", function()
    for key, mods in pairs({ h = "SHIFT", k = "SHIFT", j = "", l = "" }) do
      hl.unbind("CTRL + " .. key)
      hl.bind("CTRL + " .. key, cycleSection(mods))
    end
  end)

  local Submap = require("hyprvim.lib.submap")

  local skip = {}
  for _, name in ipairs(opts.skip) do skip[name] = true end

  local function skipped(win)
    if not win then return true end
    if win.class:sub(1, #"hyprvim-") == "hyprvim-" then return false end
    return skip[processName(win.pid)] == true
  end

  -- HyprVim's INSERT is a submap that keeps every global bind (workspaces, focus, launchers) dead
  -- while typing; dropping straight back to the global submap lets plain Escape re-enter NORMAL instead.
  Submap.registry.INSERT.on_enter = function() Submap.reset() end

  local escapePress = 0
  local escapePending = false

  hl.bind("ESCAPE", function()
    if overlayFocused() or skipped(hl.get_active_window()) then return { pass_event = true } end
    escapePress = escapePress + 1
    if escapePending then
      escapePending = false
      require("hyprvim.vim").count.clear()
      Submap.enter("NORMAL")
      return
    end
    escapePending = true
    local press = escapePress
    hl.timer(function()
      if press ~= escapePress or not escapePending then return end
      escapePending = false
      require("hyprvim.hypr").send("", "Escape")
    end, { timeout = DOUBLE_ESCAPE_MS, type = "oneshot" })
  end)

  local modes = {}
  local painted = nil

  local idleBorder = gradientProp(opts.border)

  local function setBorder(address, value)
    hl.dispatch(hl.dsp.window.set_prop({ prop = "active_border_color", value = value, window = "address:" .. address }))
  end

  for _, win in ipairs(hl.get_windows()) do setBorder(win.address, idleBorder) end

  -- A global hl.config border change re-lays out every window; a per-window prop touches only one.
  local function paint(win, color)
    if painted and (not win or painted ~= win.address) then
      setBorder(painted, idleBorder)
      painted = nil
    end
    if not win then return end
    setBorder(win.address, color)
    painted = win.address
  end

  local function restore(win)
    local mode = win and modes[win.address]
    if mode and not skipped(win) then
      Submap.enter(mode)
    elseif Submap.current ~= "reset" then
      Submap.reset()
    end
  end

  local superHeld = false

  local function paused()
    return superHeld or overlayFocused()
  end

  -- Hyprland only matches global binds in the reset submap, so while Super is held the vim submap is
  -- dropped and the window's mode is put back on release.
  hl.on("input.keyboard.key", function(keycode, _, state)
    if not SUPER_KEYS[keycode] then return end
    if state == 1 then
      superHeld = true
      if Submap.current ~= "reset" then Submap.reset() end
    else
      superHeld = false
      if not overlayFocused() then restore(hl.get_active_window()) end
    end
  end)

  hl.on("layer.opened", function()
    if overlayFocused() and Submap.current ~= "reset" then Submap.reset() end
  end)

  hl.on("layer.closed", function()
    if not paused() then restore(hl.get_active_window()) end
  end)

  hl.on("window.active", function()
    if not paused() then restore(hl.get_active_window()) end
  end)

  hl.on("keybinds.submap", function(name)
    local win = hl.get_active_window()
    if Submap.registry[name] and not isIdle(name) and skipped(win) then
      Submap.reset()
      return
    end
    if win and MODE_BORDERS[name] then modes[win.address] = name end
    if isIdle(name) then
      if win and not paused() then modes[win.address] = nil end
      paint(nil)
      return
    end
    paint(win, MODE_BORDERS[name] or PENDING_BORDER)
  end)
end

return VimMode
