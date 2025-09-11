return {
	{
		"williamboman/mason.nvim",
		config = function()
			require("mason").setup()
		end,
	},
	{
		"williamboman/mason-lspconfig.nvim",
		dependencies = { "williamboman/mason.nvim", "neovim/nvim-lspconfig" },
		config = function()
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
				-- "emmet_ls",
			}

			require("mason-lspconfig").setup({
				ensure_installed = servers,
			})

			local lspconfig = require("lspconfig")
			for _, server in ipairs(default_config_servers) do
				lspconfig[server].setup({})
			end

			local vue_language_server_path = vim.fn.stdpath("data")
				.. "/mason/packages/vue-language-server/node_modules/@vue/language-server"
			local vue_plugin = {
				name = "@vue/typescript-plugin",
				location = vue_language_server_path,
				languages = { "vue" },
				configNamespace = "typescript",
			}
			local capabilities = require("cmp_nvim_lsp").default_capabilities()
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

			lspconfig.ts_ls.setup({
				capabilities = capabilities,
				filetypes = { "typescript", "javascript", "javascriptreact", "typescriptreact", "vue" },
			})

			local venv_path = vim.fn.getcwd() .. "/.venv/bin/python"
			lspconfig.pyright.setup({
				settings = {
					python = {
						pythonPath = venv_path,
						analysis = {
							autoSearchPaths = true,
							useLibraryCodeForTypes = true,
							diagnosticMode = "workspace",
						},
					},
				},
			})

			lspconfig.omnisharp.setup({
				cmd = {
					vim.fn.stdpath("data") .. "/mason/packages/omnisharp/OmniSharp",
					"--languageserver",
					"--hostPID",
					tostring(vim.fn.getpid()),
				},
				enable_editorconfig_support = true,
				enable_roslyn_analyzers = true,
				organize_imports_on_format = true,
				enable_import_completion = true,
			})

			local border_opts = { border = "rounded" }

			vim.lsp.handlers["textDocument/hover"] = vim.lsp.with(vim.lsp.handlers.hover, border_opts)

			vim.lsp.handlers["textDocument/signatureHelp"] = vim.lsp.with(vim.lsp.handlers.signature_help, border_opts)
		end,
	},
	{ "neovim/nvim-lspconfig" },
}
