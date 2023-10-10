require("neorg").setup({
	load = {
		["core.defaults"] = {}, -- Loads default behaviour
		["core.concealer"] = {}, -- Adds pretty icons to your documents
		["core.summary"] = {}, -- Adds document stats on the footer
		["core.dirman"] = { -- Manages Neorg workspaces
			config = {
				workspaces = {
					finanzas_de_empresas = "~/notes/finanzas-de-empresas",
				},
			},
		},
	},
})
vim.api.nvim_create_autocmd({ "BufEnter", "BufWinEnter" }, {
	pattern = { "*.norg" },
	command = "set conceallevel=3",
})
