return {
	"folke/snacks.nvim",
	lazy = false, -- must not be lazy
	priority = 1000, -- should load early
	config = function()
		require("snacks").setup({
			picker = {
				enable = true,
				win = { backdrop = { transparent = true, blend = 0 } }, -- no blur/dim
			},
			notifier = { enable = true },
			image = { enable = true },

			zen = {
				enable = false,
				win = { backdrop = { transparent = true, blend = 0 } },
			},
		})
	end,
}
