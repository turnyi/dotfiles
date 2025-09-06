return {
	{
		"kdheepak/lazygit.nvim",
		cmd = { "LazyGit", "LazyGitConfig", "LazyGitCurrentFile", "LazyGitFilter", "LazyGitFilterCurrentFile" },
		dependencies = {
			"nvim-lua/plenary.nvim",
		},
		keys = {
			{ "<leader>lg", "<cmd>LazyGit<cr>", desc = "Open Lazygit" },
			{
				"<Esc><Esc>",
				[[<C-\><C-n>:q<CR>]],
				mode = "t",
				desc = "Exit LazyGit quickly",
				silent = true,
				noremap = true,
			},
		},
	},
}
