return {
  "goolord/alpha-nvim",
  dependencies = { "nvim-tree/nvim-web-devicons" },
  config = function()
    local alpha = require("alpha")
    local dashboard = require("alpha.themes.dashboard")

    dashboard.section.buttons.val = {
      dashboard.button("f", "🔍 Find File", ":Telescope find_files<CR>"),
      dashboard.button("r", "🕘 Recent Files", ":Telescope oldfiles<CR>"),
      dashboard.button("g", "🔎 Live Grep", ":Telescope live_grep<CR>"),
      dashboard.button("q", "🚪 Quit", ":qa<CR>"),
    }

    dashboard.opts.layout[1].val = 5

    alpha.setup(dashboard.opts)
  end,
}
