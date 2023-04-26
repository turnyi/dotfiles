require('plugins.lsp')
require('plugins.telescope')
require('plugins.null-ls')


vim.api.nvim_exec([[
augroup AutoFormat
  autocmd!
  autocmd BufWritePre * lua vim.lsp.buf.format()
augroup END
]], true)

