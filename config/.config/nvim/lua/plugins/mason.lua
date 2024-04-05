require("mason").setup({
	ui = {
		icons = {
			package_installed = "✓",
			package_pending = "➜",
			package_uninstalled = "✗",
		},
	},
})
local mlsp = require("mason-lspconfig")
mlsp.setup({
	ensure_installed = { "typos_lsp", "cspell" },
})
