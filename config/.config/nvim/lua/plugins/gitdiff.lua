return {
	{
		"tpope/vim-fugitive",
		cmd = { "Git", "Gdiffsplit", "Gvdiffsplit", "Gedit", "Gwrite", "Gread", "Gblame" },
		keys = {
			{ "<leader>gs", ":Git<CR>", desc = "Git status" },
			{ "<leader>gd", ":Gvdiffsplit<CR>", desc = "Git diff split" },
			{ "<leader>gb", ":Git blame<CR>", desc = "Git blame" },
		},
	},
}
