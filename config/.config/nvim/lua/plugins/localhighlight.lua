vim.api.nvim_set_hl(0, "LocalHighlightUnderline", { underline = true })

return {
	"tzachar/local-highlight.nvim",
	config = function()
		require("local-highlight").setup({
			hlgroup = "LocalHighlightUnderline",
			cw_hlgroup = "LocalHighlightUnderline",
		})
	end,
}
