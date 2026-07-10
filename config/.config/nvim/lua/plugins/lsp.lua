return {
	{
		"williamboman/mason.nvim",
		config = function()
			require("mason").setup()
		end,
	},
	{
		"williamboman/mason-lspconfig.nvim",
		dependencies = {
			"williamboman/mason.nvim",
			"neovim/nvim-lspconfig",
			"hrsh7th/cmp-nvim-lsp", -- for capabilities
		},
		config = function()
			-- All servers you want installed
			local servers = {
				"lua_ls",
				"ts_ls",
				"html",
				"cssls",
				"eslint",
				"jsonls",
				"bashls",
				"pyright",
				"clangd",
				"omnisharp",
				"vtsls",
			}

			-- Servers you want with "default" simple config
			local default_config_servers = {
				"lua_ls",
				"html",
				"cssls",
				"eslint",
				"jsonls",
				"bashls",
				"pyright",
				"clangd",
				"omnisharp",
			}

			require("mason-lspconfig").setup({
				ensure_installed = servers,
				-- you control enabling with vim.lsp.enable()
				automatic_installation = false,
			})

			------------------------------------------------------------------
			-- LSP configs (new API)
			------------------------------------------------------------------
			local capabilities = require("cmp_nvim_lsp").default_capabilities()

			-- 1) default servers with plain config
			for _, server in ipairs(default_config_servers) do
				vim.lsp.config(server, {
					capabilities = capabilities,
				})
			end

			-- 2) Vue + vtsls integration
			local vue_language_server_path = vim.fn.stdpath("data")
				.. "/mason/packages/vue-language-server/node_modules/@vue/language-server"

			local vue_plugin = {
				name = "@vue/typescript-plugin",
				location = vue_language_server_path,
				languages = { "vue" },
				configNamespace = "typescript",
			}

			vim.lsp.config("vtsls", {
				capabilities = capabilities,
				settings = {
					vtsls = {
						tsserver = {
							globalPlugins = {
								vue_plugin,
							},
						},
					},
				},
				filetypes = { "vue" },
			})

			vim.lsp.config("ts_ls", {
				capabilities = capabilities,
				filetypes = {
					"typescript",
					"javascript",
					"javascriptreact",
					"typescriptreact",
					"vue",
				},
			})

			-- Enable everything
			vim.lsp.enable(vim.list_extend(vim.list_extend({}, default_config_servers), { "vtsls", "ts_ls" }))

			------------------------------------------------------------------
			-- UI tweaks
			------------------------------------------------------------------
			vim.lsp.config("*", {
				handlers = {
					["textDocument/hover"] = function(err, result, ctx, config)
						vim.lsp.handlers.hover(err, result, ctx, vim.tbl_extend("force", config or {}, { border = "rounded" }))
					end,
					["textDocument/signatureHelp"] = function(err, result, ctx, config)
						vim.lsp.handlers.signature_help(err, result, ctx, vim.tbl_extend("force", config or {}, { border = "rounded" }))
					end,
				},
			})
		end,
	},
	{ "neovim/nvim-lspconfig" },
}
