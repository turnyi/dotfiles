require("plugins.lsp")
require("plugins.telescope")
require("plugins.catppuccin")
require("plugins.null-ls")
require("plugins.nvim-cmp")
require("plugins.trouble")
require("plugins.bufferline")
require("plugins.treesiter")
require("plugins.whichKey")
require("plugins.smoothCursor")
require("plugins.neorg")
require("plugins.chatgpt")
require("plugins.diagnostics")

vim.api.nvim_exec(
	[[
augroup AutoFormat
  autocmd!
  autocmd BufWritePre * lua vim.lsp.buf.format(); vim.cmd('stopinsert')
augroup END
]],
	true
)

-- Add a keymapping to open the diagnostic float
vim.api.nvim_set_keymap(
	"n",
	"g a",
	':lua vim.diagnostic.open_float({scope="line"})<CR>',
	{ noremap = true, silent = true }
)
vim.api.nvim_set_keymap(
	"n",
	"g a",
	':lua vim.diagnostic.open_float({scope="line"})<CR>',
	{ noremap = true, silent = true }
)
