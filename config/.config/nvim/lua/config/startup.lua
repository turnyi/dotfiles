vim.api.nvim_create_autocmd("VimEnter", {
  callback = function()
    local argc = vim.fn.argc() 
    local arg = vim.fn.argv(0) 

    if argc == 0 then
      require("telescope.builtin").find_files()
    end

    if argc == 1 and vim.fn.isdirectory(arg) == 1 then
      vim.cmd("enew") 
      vim.cmd("cd " .. arg) 
      require("telescope.builtin").find_files()
    end
  end
})
