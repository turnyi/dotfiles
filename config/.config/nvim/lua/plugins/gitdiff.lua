return {
	{
		"tpope/vim-fugitive",
		cmd = { "Git", "Gdiffsplit", "Gvdiffsplit", "Gedit", "Gwrite", "Gread", "Gblame", "Glog", "Gpush", "Gpull" },
		keys = {
			{ "<leader>gs", ":vert Git<CR>", desc = "Git status", silent = true },
			{ "<leader>gd", ":Gvdiffsplit<CR>", desc = "Git diff split", silent = true },
			{ "<leader>gb", ":Git blame<CR>", desc = "Git blame", silent = true },
			{ "<leader>gl", ":Git log<CR>", desc = "Git log", silent = true },
			{ "<leader>gP", ":Git push<CR>", desc = "Git push", silent = true },
			{ "<leader>gF", ":Git pull<CR>", desc = "Git pull", silent = true },
		},
	},
}
