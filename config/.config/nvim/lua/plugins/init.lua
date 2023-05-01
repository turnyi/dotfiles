require('plugins.lsp')
require('plugins.telescope')
require('plugins.null-ls')
require('plugins.nvim-cmp')
require('plugins.trouble')

vim.api.nvim_exec([[
augroup AutoFormat
  autocmd!
  autocmd BufWritePre * lua vim.lsp.buf.format()
augroup END
]], true)

-- Add a keymapping to open the diagnostic float
vim.api.nvim_set_keymap('n', 'g a', ':lua vim.diagnostic.open_float({scope="line"})<CR>',
  { noremap = true, silent = true })
