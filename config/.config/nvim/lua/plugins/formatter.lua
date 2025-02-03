return {
	{
		"stevearc/conform.nvim",
		dependencies = { "williamboman/mason.nvim" },
		config = function()
			local conform = require("conform")

			-- Formatter list (excluding gofmt)
			local formatters = {
				"prettier", -- JavaScript, TypeScript, HTML, CSS
				"stylua", -- Lua
				"black", -- Python
				"clang-format", -- C, C++
				"shfmt", -- Shell scripts
				"isort", -- Python import sorting
				"rustfmt", -- Rust
				"biome", -- Alternative to Prettier for JS/TS
			}

			-- Ensure formatters are installed via Mason
			require("mason").setup()
			require("mason-tool-installer").setup({
				ensure_installed = formatters,
			})

			-- Configure Conform
			conform.setup({
				formatters_by_ft = {
					lua = { "stylua" },
					javascript = { "prettier" },
					typescript = { "prettier" },
					json = { "prettier" },
					html = { "prettier" },
					css = { "prettier" },
					scss = { "prettier" },
					python = { "black", "isort" },
					c = { "clang-format" },
					cpp = { "clang-format" },
					sh = { "shfmt" },
					go = { "gofmt" }, -- ✅ Keep it here (Go toolchain must be installed)
					rust = { "rustfmt" },
				},
				format_on_save = {
					timeout_ms = 500,
					lsp_fallback = true,
				},
			})

			-- Autoformat on save
			vim.api.nvim_create_autocmd("BufWritePre", {
				callback = function()
					conform.format({ async = false })
				end,
			})
		end,
	},
	{
		"williamboman/mason.nvim",
		dependencies = { "WhoIsSethDaniel/mason-tool-installer.nvim" },
	},
}
