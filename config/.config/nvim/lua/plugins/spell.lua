local function find_cspell_recursive(directory)
	if vim.fn.isdirectory(directory) == 0 then
		return nil
	end
	local cspell_path = directory .. "/cspell.json"
	if vim.fn.filereadable(cspell_path) == 1 then
		return cspell_path
	end
	local parent_directory = vim.fn.fnamemodify(directory, ":h")
	if parent_directory == directory then
		return nil
	end
	return find_cspell_recursive(parent_directory)
end

local config = {
	find_json = function()
		local cwd = vim.fn.getcwd()
		local cspell_path = find_cspell_recursive(cwd)
		return cspell_path
	end,
	command = "/opt/homebrew/bin/cspell",
}

return {
	{
		"nvimtools/none-ls.nvim",
		event = "VeryLazy",
		dependencies = { "davidmh/cspell.nvim" },
		opts = function()
			local null_ls = require("null-ls")
			local cspell = require("cspell")
			null_ls.setup({
				sources = {
					cspell.diagnostics.with({ config = config }),
					cspell.code_actions.with({ config = config }),
				},
			})
		end,
	},
}
