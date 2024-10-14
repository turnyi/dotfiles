local null_ls = require("null-ls")

local formattin = null_ls.builtins.formatting
local function find_cspell_recursive(directory)
  -- Check if the directory exists
  if vim.fn.isdirectory(directory) == 0 then
    return nil
  end

  -- Check if cspell.json exists in the current directory
  local cspell_path = directory .. "/cspell.json"
  print(cspell_path)
  if vim.fn.filereadable(cspell_path) == 1 then
    return cspell_path
  end

  -- Get the parent directory
  local parent_directory = vim.fn.fnamemodify(directory, ":h")

  -- If we've reached the root directory, return nil
  if parent_directory == directory then
    return nil
  end

  -- Recursively search in the parent directory
  return find_cspell_recursive(parent_directory)
end
local cspell_with = {
  config = {
    find_json = function()
      -- Get the current working directory
      local cwd = vim.fn.getcwd()

      -- Find cspell.json recursively starting from the current working directory
      local cspell_path = find_cspell_recursive(cwd)

      return cspell_path
    end,
  },
}
local sources = {
  -- formattin.eslint,
  formattin.prettier,
  formattin.stylua,
  formattin.rustfmt,
  formattin.shfmt,
  formattin.goimports,
  formattin.black,
  formattin.isort,
  formattin.sqlformat,
  null_ls.builtins.diagnostics.cspell.with(cspell_with),
  null_ls.builtins.code_actions.cspell.with(cspell_with),
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

vim.api.nvim_exec(
  [[
augroup AutoFormat
  autocmd!
  autocmd BufWritePre * lua vim.lsp.buf.format(); vim.cmd('stopinsert')
augroup END
]],
  true
)
