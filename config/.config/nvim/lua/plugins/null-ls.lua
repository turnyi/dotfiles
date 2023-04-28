local null_ls = require('null-ls')

local formattin = null_ls.builtins.formatting

local sources = {
  formattin.prettier,
  formattin.stylua,
  formattin.eslint,
  formattin.rustfmt,
  formattin.shfmt,
  formattin.goimports,
  formattin.black,
  formattin.isort,
  formattin.sqlformat,
}

null_ls.setup({
  sources = sources
})
