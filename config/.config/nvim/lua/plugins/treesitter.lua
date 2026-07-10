return {
	"nvim-treesitter/nvim-treesitter",
	branch = "main",
	build = ":TSUpdate",
	lazy = false,
	config = function()
		-- highlight and indent are now Neovim built-ins; this plugin is just a parser manager
		require("nvim-treesitter.install").install(
			"c",
			"lua",
			"vim",
			"vimdoc",
			"query",
			"elixir",
			"heex",
			"javascript",
			"html",
			"typescript",
			"yaml",
			"python",
			"vue",
			"sql"
		)
	end,
}
