vim.opt.smarttab = true
vim.opt.number = true
vim.opt.relativenumber = true
vim.opt.tabstop = 2
vim.opt.shiftwidth = 2
vim.opt.softtabstop = 2
vim.opt.expandtab = true
vim.opt.autoindent = true
vim.opt.smartindent = true
vim.opt.breakindent = true
vim.opt.mouse = "a"
vim.opt.clipboard = "unnamedplus"
vim.opt.cmdheight = 1
vim.opt.completeopt = { "menuone", "preview" }
vim.opt.conceallevel = 0
vim.opt.confirm = true
vim.opt.fileencoding = "utf-8"
vim.opt.hidden = true
vim.opt.hlsearch = true
vim.opt.incsearch = true
vim.opt.matchpairs:append("<:>")
vim.opt.belloff = "all"
vim.opt.ignorecase = false
vim.opt.smartcase = true
vim.opt.swapfile = false
vim.opt.wrap = false
vim.opt.numberwidth = 4
vim.opt.pumheight = 10
vim.opt.scrolloff = 8
vim.opt.showmatch = true
vim.opt.signcolumn = "yes"
vim.opt.splitbelow = true
vim.opt.splitright = true
vim.opt.termguicolors = true
vim.opt.timeoutlen = 500
vim.opt.ttyfast = true
vim.opt.undodir = vim.fn.expand("~/.vim/undodir")
vim.opt.undofile = true
vim.opt.updatetime = 300
vim.opt.wildmenu = true
vim.opt.wildmode = { "longest", "list" }
vim.opt.laststatus = 3
vim.opt.foldmethod = "expr"
vim.opt.pumblend = 0
vim.opt.hlsearch = false

vim.api.nvim_create_autocmd("CursorMoved", {
	pattern = "*",
	callback = function()
		vim.opt.relativenumber = true
		vim.opt.number = true
	end,
})

vim.opt.clipboard = "unnamedplus"

vim.opt.scrolloff = 8

vim.opt.fillchars = { eob = " " }

vim.diagnostic.config({
	float = {
		border = "rounded", -- You can use "single", "double", "shadow", or "rounded"
	},
})
