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
				"emmet_ls",
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
				"volar",
				"emmet_ls",
			}

			require("mason-lspconfig").setup({
				ensure_installed = servers,
			})

			local lspconfig = require("lspconfig")
			for _, server in ipairs(default_config_servers) do
				lspconfig[server].setup({})
			end

			lspconfig.ts_ls.setup({
				init_options = {
					plugins = {
						{
							name = "@vue/typescript-plugin",
							location = "/home/turny/.npm-global/lib",
							languages = { "vue" },
						},
					},
				},
				filetypes = { "typescript", "javascript", "javascriptreact", "typescriptreact", "vue" },
			})

			lspconfig.volar.setup({
				filetypes = { "vue" },
				capabilities = capabilities,
				init_options = {
					typescript = {
						tsdk = vim.fn.stdpath("data")
							.. "/mason/packages/typescript-language-server/node_modules/typescript/lib",
					},
				},
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

			-- ✅ Configuración específica para omnisharp
			lspconfig.omnisharp.setup({
				cmd = {
					vim.fn.stdpath("data") .. "/mason/packages/omnisharp/OmniSharp", -- ✅ el binario correcto
					"--languageserver",
					"--hostPID",
					tostring(vim.fn.getpid()),
				},
				enable_editorconfig_support = true,
				enable_roslyn_analyzers = true,
				organize_imports_on_format = true,
				enable_import_completion = true,
			})
		end,
	},
	{ "neovim/nvim-lspconfig" },
}
