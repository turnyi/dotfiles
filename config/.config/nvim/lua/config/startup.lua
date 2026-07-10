vim.api.nvim_create_autocmd("RecordingEnter", {
  callback = function()
    local reg = vim.fn.reg_recording()
    vim.notify("recording @" .. reg, vim.log.levels.INFO, {
      title = "Macro",
      id = "macro_recording",
      timeout = false,
    })
  end,
})

vim.api.nvim_create_autocmd("RecordingLeave", {
  callback = function()
    vim.schedule(function()
      Snacks.notifier.hide("macro_recording")
    end)
  end,
})

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
