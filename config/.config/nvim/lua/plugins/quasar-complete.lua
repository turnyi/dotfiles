return {
  "quasar-complete",
  dir = vim.fn.stdpath("config") .. "/lua/quasar-complete",
  dependencies = {
    "hrsh7th/nvim-cmp",
  },
  config = function()
    require("quasar-complete").setup({
      filetypes = { "vue", "javascript", "typescript", "html" },
      max_suggestions = 10, -- Optimized for better performance
      trigger_characters = { "q-", "text-", "bg-", "border-", "shadow-", "row", "col", "flex" },
      auto_trigger = true, -- Enable automatic suggestions
      debounce_ms = 50, -- Faster response time
      enable_component_completion = true, -- Enable Quasar component suggestions
    })
  end,
}
