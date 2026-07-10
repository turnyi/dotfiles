vim.g.mapleader = " "
vim.g.maplocalleader = ","

-- Neovim 0.12 removed vim.treesitter.ft_to_lang; shim for plugins that haven't updated yet
if not vim.treesitter.ft_to_lang then
	vim.treesitter.ft_to_lang = function(ft)
		return vim.treesitter.language.get_lang(ft) or ft
	end
end

require("config.lazy")
require("config")

-- Patch nvim-treesitter parsers module for plugins (e.g. telescope) that use
-- the old ft_to_lang API removed in the nvim-treesitter main branch rewrite
vim.schedule(function()
	local ok, parsers = pcall(require, "nvim-treesitter.parsers")
	if ok and not parsers.ft_to_lang then
		parsers.ft_to_lang = function(ft)
			return vim.treesitter.language.get_lang(ft) or ft
		end
	end
end)
