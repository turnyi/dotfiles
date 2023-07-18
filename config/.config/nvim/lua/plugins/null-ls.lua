local null_ls = require("null-ls")

local formattin = null_ls.builtins.formatting

local sources = {
	formattin.eslint,
	-- formattin.prettier,
	formattin.stylua,
	formattin.rustfmt,
	formattin.shfmt,
	formattin.goimports,
	formattin.black,
	formattin.isort,
	formattin.sqlformat,
}

local augroup = vim.api.nvim_create_augroup("LspFormatting", {})

null_ls.setup({
	debug = true,
	on_attach = function(client, bufnr)
		vim.lsp.buf.format({ timeout_ms = 5000 })
		if client.supports_method("textDocument/formatting") then
			vim.api.nvim_clear_autocmds({ group = augroup, buffer = bufnr })
			vim.api.nvim_create_autocmd("BufWritePre", {
				group = augroup,
				buffer = bufnr,
				callback = function()
					vim.lsp.buf.format()
				end,
			})
		end
	end,
	sources = sources,
})

return null_ls
