local M = {}

-- Default configuration
local default_config = {
  filetypes = { "vue", "javascript", "typescript", "html" },
  max_suggestions = 10,
  trigger_characters = { "q-", "text-", "bg-", "border-", "shadow-", "row", "col", "flex" },
  enable_builtin_completion = true,
  auto_trigger = true, -- New option for automatic triggering
  debounce_ms = 50, -- Reduced debounce for faster response
}

-- Current configuration
local config = vim.deepcopy(default_config)

-- Performance caches
local debounce_timer = nil
local last_line = nil
local last_col = nil
local last_detection_result = nil
local detection_cache_time = 0
local CACHE_DURATION = 100 -- Cache detection result for 100ms

-- Cache for Quasar classes
local quasar_classes = nil
local class_prefix_cache = {} -- Cache for prefix-based filtering

-- Load Quasar classes from data file
local function load_quasar_classes()
  if quasar_classes then
    return quasar_classes
  end

  local data_path = vim.fn.stdpath("config") .. "/lua/quasar-complete/data/quasar-classes.json"
  local file = io.open(data_path, "r")
  if not file then
    vim.notify("Quasar completion: Could not find quasar-classes.json", vim.log.levels.WARN)
    return {}
  end

  local content = file:read("*all")
  file:close()

  local ok, data = pcall(vim.json.decode, content)
  if not ok then
    vim.notify("Quasar completion: Invalid JSON in quasar-classes.json", vim.log.levels.ERROR)
    return {}
  end

  quasar_classes = data.classes or {}
  return quasar_classes
end

-- Check if current buffer is in a supported filetype
local function is_supported_filetype()
  local ft = vim.bo.filetype
  for _, supported_ft in ipairs(config.filetypes) do
    if ft == supported_ft then
      return true
    end
  end
  return false
end

-- Optimized class attribute detection with caching
local function is_in_class_attribute()
  if not is_supported_filetype() then
    return false
  end

  local line = vim.api.nvim_get_current_line()
  local col = vim.api.nvim_win_get_cursor(0)[2] + 1
  local current_time = vim.loop.now()

  -- Use cached result if within cache duration and position hasn't changed
  if last_line == line and last_col == col and 
     last_detection_result ~= nil and 
     (current_time - detection_cache_time) < CACHE_DURATION then
    return last_detection_result
  end

  -- Update cache info
  last_line = line
  last_col = col
  detection_cache_time = current_time

  -- Fast pre-check: if cursor is not near quotes, exit early
  local char_before = col > 1 and line:sub(col - 1, col - 1) or ""
  local char_after = line:sub(col, col)
  if char_before ~= '"' and char_before ~= "'" and 
     char_after ~= '"' and char_after ~= "'" and
     not line:sub(1, col):find('class%s*=') then
    last_detection_result = false
    return false
  end

  -- Optimized pattern matching
  local patterns = {
    'class%s*=%s*["\']',
    ':class%s*=%s*["\']',
    'className%s*=%s*["\']',
    'classList%s*=%s*["\']',
  }

  for _, pattern in ipairs(patterns) do
    local attr_start = string.find(line, pattern)
    if attr_start and attr_start < col then
      local quote_start = string.find(line, '["\']', attr_start)
      if quote_start and col > quote_start then
        local quote_char = string.sub(line, quote_start, quote_start)
        
        -- Find closing quote efficiently
        local quote_end = string.find(line, quote_char, quote_start + 1)
        
        if quote_end then
          -- Complete attribute: cursor must be inside quotes
          if col <= quote_end then
            last_detection_result = true
            return true
          end
        else
          -- Incomplete attribute: check if we're still in context
          local remaining = string.sub(line, col)
          if not string.find(remaining, quote_char) then
            last_detection_result = true
            return true
          end
        end
      end
    end
  end

  last_detection_result = false
  return false
end

-- Optimized completion filtering with prefix caching
local function get_filtered_classes(current_word)
  if not current_word or current_word == "" then
    return quasar_classes or {}
  end

  -- Check cache first
  if class_prefix_cache[current_word] then
    return class_prefix_cache[current_word]
  end

  local classes = load_quasar_classes()
  local filtered = {}
  
  -- Efficient prefix matching
  for _, class in ipairs(classes) do
    if class:find(current_word, 1, true) == 1 then
      table.insert(filtered, class)
      if #filtered >= config.max_suggestions then
        break
      end
    end
  end

  -- Cache the result for future use
  class_prefix_cache[current_word] = filtered
  
  return filtered
end

-- Ultra-fast debounced completion trigger
local function trigger_completion()
  -- Clear existing timer
  if debounce_timer then
    debounce_timer:stop()
    debounce_timer:close()
    debounce_timer = nil
  end

  -- Create new timer with optimized callback
  debounce_timer = vim.loop.new_timer()
  debounce_timer:start(config.debounce_ms, 0, vim.schedule_wrap(function()
    if debounce_timer then
      debounce_timer:stop()
      debounce_timer:close()
      debounce_timer = nil
    end

    if not is_in_class_attribute() then
      return
    end

    local cmp_ok, cmp = pcall(require, "cmp")
    if cmp_ok and vim.fn.pumvisible() == 0 then
      cmp.complete({
        config = {
          sources = {
            { name = "quasar" }
          }
        }
      })
    elseif config.enable_builtin_completion and vim.fn.pumvisible() == 0 then
      vim.fn.feedkeys(vim.api.nvim_replace_termcodes("<C-x><C-u>", true, false, true), "n")
    end
  end))
end

-- Get completion items for nvim-cmp
function M.get_cmp_source()
  local classes = load_quasar_classes()

  return {
    complete = function(self, request, callback)
      if not is_in_class_attribute() then
        callback({ items = {}, isIncomplete = false })
        return
      end

      -- Get the current word being typed (optimized)
      local line = vim.api.nvim_get_current_line()
      local col = vim.api.nvim_win_get_cursor(0)[2] + 1

      -- Fast word extraction
      local word_start = col
      local line_sub = line:sub(1, col - 1)
      
      for i = #line_sub, 1, -1 do
        if not line_sub:sub(i, i):match("[%w-]") then
          word_start = i + 1
          break
        end
      end

      local current_word = line:sub(word_start, col - 1)
      
      -- Get filtered classes (with caching)
      local filtered_classes = get_filtered_classes(current_word)
      local items = {}

      -- Build completion items efficiently
      for i, class in ipairs(filtered_classes) do
        if i > config.max_suggestions then
          break
        end
        
        table.insert(items, {
          label = class,
          kind = require("cmp.types").lsp.CompletionItemKind.Class,
          documentation = {
            kind = "markdown",
            value = string.format("**Quasar CSS Class**\n\n`%s`", class),
          },
        })
      end

      callback({ items = items, isIncomplete = false })
    end,
  }
end

-- Setup function
function M.setup(user_config)
  config = vim.tbl_deep_extend("force", default_config, user_config or {})

  -- Pre-load classes for better performance
  load_quasar_classes()

  -- Register with nvim-cmp if available
  local cmp_ok, cmp = pcall(require, "cmp")
  if cmp_ok then
    cmp.register_source("quasar", M.get_cmp_source())
  end

  -- Setup automatic completion triggering if enabled
  if config.auto_trigger then
    vim.api.nvim_create_autocmd("InsertCharPre", {
      pattern = "*",
      callback = function()
        if not is_in_class_attribute() then
          return
        end

        local char = vim.v.char

        -- Only trigger for relevant characters (optimized)
        if char:match("[%w-]") or char == " " then
          trigger_completion()
        end
      end,
    })

    -- Also trigger on cursor movement within class attributes
    vim.api.nvim_create_autocmd({"CursorMovedI", "InsertEnter"}, {
      pattern = "*",
      callback = function()
        if not is_in_class_attribute() then
          return
        end

        trigger_completion()
      end,
    })
  end

  vim.notify("Quasar completion plugin loaded with ultra-fast performance!", vim.log.levels.INFO)
end

-- Expose functions for debugging
M.is_in_class_attribute = is_in_class_attribute
M.load_quasar_classes = load_quasar_classes

return M
