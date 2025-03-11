local M = {}
local opts = { noremap = true, silent = true }
local diagnostic = require("vim.diagnostic")

local nvim_set_keymap = vim.api.nvim_set_keymap
local vim_set = vim.keymap.set
local vim_cmd = vim.cmd

local global = vim.g

local cmp = require("cmp")
function OpenFloatingDiagnostics()
	diagnostic.open_float({ scope = "line", border = "rounded" })
end

M.generalMappings = function()
	global.mapleader = " "
	global.maplocalleader = "\\"
	nvim_set_keymap("n", "<C-s>", ":w<CR>", opts)
	vim_set("n", "<leader>w", function()
		vim.wo.wrap = not vim.wo.wrap
	end, { desc = "Toggle line wrap" })
	nvim_set_keymap("n", "<S-T>", ":lua OpenFloatingDiagnostics()<CR>", { noremap = true, silent = true })
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
	vim_set("n", "gld", function()
		vim_cmd("vsplit")
		vim_cmd("wincmd h")
		require("telescope.builtin").lsp_definitions()
	end, { noremap = true, silent = true })
	vim_set("n", "grd", function()
		vim_cmd("vsplit")
		vim_cmd("wincmd h")
		require("telescope.builtin").lsp_definitions()
	end, { noremap = true, silent = true })
end
M.telescopeBuffers = {
	["<c-d>"] = "delete_buffer",
}

M.lspMappings = function()
	local buf = vim.lsp.buf

	vim_set("n", "gD", function()
		vim_cmd("vsplit | lua vim.lsp.buf.definition()")
	end, { noremap = true, silent = true })
	vim_set("n", "ga", buf.code_action, { noremap = true, silent = true })
end

M.troubleMappings = function()
	nvim_set_keymap(
		"n",
		"<leader>tg",
		"<cmd>Trouble diagnostics toggle<CR>",
		{ noremap = true, silent = true, desc = "Diagnostics (Trouble)" }
	)
	nvim_set_keymap(
		"n",
		"<leader>tl",
		"<cmd>Trouble diagnostics toggle filter.buf=0<CR>",
		{ noremap = true, silent = true, desc = "Buffer Diagnostics (Trouble)" }
	)
end

M.navigation = {
	{ "<c-h>", "<cmd><C-U>TmuxNavigateLeft<cr>" },
	{ "<c-j>", "<cmd><C-U>TmuxNavigateDown<cr>" },
	{ "<c-k>", "<cmd><C-U>TmuxNavigateUp<cr>" },
	{ "<c-l>", "<cmd><C-U>TmuxNavigateRight<cr>" },
	{ "<c-\\>", "<cmd><C-U>TmuxNavigatePrevious<cr>" },
}

M.autocomplete = {
	["<C-Space>"] = cmp.mapping.complete(),
	["<CR>"] = cmp.mapping.confirm({ select = true }),
	["<Tab>"] = cmp.mapping.select_next_item(),
	["<S-Tab>"] = cmp.mapping.select_prev_item(),
}

M.spell = function()
	global.spelllang_toggle = { "en", "es" }
	global.current_spelllang_index = 1
	function ToggleSpellLang()
		vim.g.current_spelllang_index = vim.g.current_spelllang_index % #vim.g.spelllang_toggle + 1
		local new_lang = vim.g.spelllang_toggle[vim.g.current_spelllang_index]
		vim.opt.spelllang = new_lang
		print("Spell language set to: " .. new_lang)
	end
	vim_set("n", "<leader>sl", ToggleSpellLang, { desc = "Toggle Spell Language (EN/ES)" })
end

M.init = function()
	M.generalMappings()
	M.saveMappings()
	M.telescope()
	M.lspMappings()
	M.spell()
	M.troubleMappings()
end
return M
