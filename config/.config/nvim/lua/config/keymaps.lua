local M = {}
local opts = { noremap = true, silent = true }

local nvim_set_keymap = vim.api.nvim_set_keymap

local global = vim.g

local cmp = require("cmp")
M.generalMappings = function()
	global.mapleader = " "
	global.maplocalleader = "\\"
end

M.saveMappings = function()
	nvim_set_keymap("n", "<C-s>", ":w<CR>", opts)
	nvim_set_keymap("i", "<C-s>", "<Esc>:w<CR>a", opts)
	nvim_set_keymap("v", "<C-s>", "<Esc>:w<CR>gv", opts)
end

M.telescope = function()
	nvim_set_keymap("n", "<C-p>", ":Telescope find_files<CR>", opts)
	nvim_set_keymap("n", "<C-b>", ":Telescope file_browser path=%:p:h select_buffer=true<CR>", opts)
	nvim_set_keymap("n", "<C-i>", ":Telescope buffers<CR>", opts)
	nvim_set_keymap("n", "<leader>fs", ":Telescope live_grep_args<CR>", opts)
	nvim_set_keymap("n", "gd", "<cmd>Telescope lsp_definitions<CR>", { noremap = true, silent = true })
	nvim_set_keymap("n", "ga", "<cmd>Telescope lsp_code_actions<CR>", { noremap = true, silent = true })
end

M.lspMappings = function()
	local buf = vim.lsp.buf

	vim.keymap.set("n", "gD", function()
		vim.cmd("vsplit | lua vim.lsp.buf.definition()")
	end, { noremap = true, silent = true })
	vim.keymap.set("n", "ga", buf.code_action, { noremap = true, silent = true })
end

M.trouble = {
	{
		"<leader>xx",
		"<cmd>Trouble diagnostics toggle<cr>",
		desc = "Diagnostics (Trouble)",
	},
	{
		"<leader>xX",
		"<cmd>Trouble diagnostics toggle filter.buf=0<cr>",
		desc = "Buffer Diagnostics (Trouble)",
	},
	{
		"<leader>cs",
		"<cmd>Trouble symbols toggle focus=false<cr>",
		desc = "Symbols (Trouble)",
	},
	{
		"<leader>cl",
		"<cmd>Trouble lsp toggle focus=false win.position=right<cr>",
		desc = "LSP Definitions / references / ... (Trouble)",
	},
	{
		"<leader>xL",
		"<cmd>Trouble loclist toggle<cr>",
		desc = "Location List (Trouble)",
	},
}

M.navigation = {
	{ "<c-h>", "<cmd><C-U>TmuxNavigateLeft<cr>" },
	{ "<c-j>", "<cmd><C-U>TmuxNavigateDown<cr>" },
	{ "<c-k>", "<cmd><C-U>TmuxNavigateUp<cr>" },
	{ "<c-l>", "<cmd><C-U>TmuxNavigateRight<cr>" },
	{ "<c-\\>", "<cmd><C-U>TmuxNavigatePrevious<cr>" },
}
M.init = function()
	M.generalMappings()
	M.saveMappings()
	M.telescope()
	M.lspMappings()
end

M.autocomplete = {
	["<C-Space>"] = cmp.mapping.complete(), -- Show completion menu manually
	["<CR>"] = cmp.mapping.confirm({ select = true }), -- Confirm selection
	["<Tab>"] = cmp.mapping.select_next_item(), -- Navigate forward
	["<S-Tab>"] = cmp.mapping.select_prev_item(), -- Navigate backward
}

return M
