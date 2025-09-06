return {
	"nvim-telescope/telescope.nvim",
	tag = "0.1.8",
	dependencies = {
		"nvim-lua/plenary.nvim",
		{ "nvim-telescope/telescope-fzf-native.nvim", build = "make" },
		{ "nvim-telescope/telescope-file-browser.nvim" },
		{ "nvim-telescope/telescope-live-grep-args.nvim" },
		{ "mickael-menu/zk-nvim" },
	},
	config = function()
		local telescope = require("telescope")
		local actions = require("telescope.actions")

		telescope.setup({
			defaults = {
				prompt_prefix = "🔍 ",
				selection_caret = "→ ",
				layout_strategy = "horizontal",
				layout_config = {
					prompt_position = "top",
				},
				sorting_strategy = "ascending",
				file_ignore_patterns = {
					"%.git/",
					"node_modules/",
				},
				hidden = true,
			},
			extensions = {
				fzf = {},
				file_browser = {
					hidden = { file_browser = true, folder_browser = true },
					respect_gitignore = false,
				},
			live_grep_args = {
				auto_quoting = true,
				default_opts = {
					additional_args = { "--hidden" },
				},
			},
				zk = {},
			},
		})

		telescope.load_extension("fzf")
		telescope.load_extension("file_browser")
		telescope.load_extension("live_grep_args")
		telescope.load_extension("zk")
		local hl = vim.api.nvim_set_hl
		hl(0, "TelescopeNormal", { bg = "none" })
		hl(0, "TelescopeBorder", { bg = "none" })
		hl(0, "TelescopePromptNormal", { bg = "none" })
		hl(0, "TelescopePromptBorder", { bg = "none" })
		hl(0, "TelescopeResultsNormal", { bg = "none" })
		hl(0, "TelescopeResultsBorder", { bg = "none" })
		hl(0, "TelescopePreviewNormal", { bg = "none" })
		hl(0, "TelescopePreviewBorder", { bg = "none" })
	end,
}
