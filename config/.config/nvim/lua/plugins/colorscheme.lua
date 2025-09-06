return {
	{
		"catppuccin/nvim",
		name = "catppuccin",
		priority = 1000,

		config = function()
			require("catppuccin").setup({
				transparent_background = true,
				flavor = "machiato",
			})
			vim.cmd("colorscheme catppuccin")
		end,
	},
	{
		"rebelot/kanagawa.nvim",
		name = "kanagawa",
		priority = 1000,
		config = function()
			require("kanagawa").setup({
				compile = false, -- enable compiling the colorscheme
				undercurl = true, -- enable undercurls
				commentStyle = { italic = true },
				functionStyle = {},
				keywordStyle = { italic = true },
				statementStyle = { bold = true },
				typeStyle = {},
				transparent = true, -- do not set background color
				dimInactive = false, -- dim inactive window `:h hl-NormalNC`
				terminalColors = true, -- define vim.g.terminal_color_{0,17}
				colors = { -- add/modify theme and palette colors
					palette = {},
					theme = { wave = {}, lotus = {}, dragon = {}, all = {} },
				},
				overrides = function(colors) -- add/modify highlights
					return {
						Normal = { bg = "none" },
						NormalNC = { bg = "none" },
						SignColumn = { bg = "none" },
						FoldColumn = { bg = "none" },
						LineNr = { bg = "none" },
						CursorLine = { bg = "none" },
						CursorLineNr = { bg = "none" },
						EndOfBuffer = { bg = "none" },

						-- splits & borders
						WinSeparator = { bg = "none" },

						-- tabs / status / cmdline
						TabLine = { bg = "none" },
						TabLineFill = { bg = "none" },
						TabLineSel = { bg = "none" },
						StatusLine = { bg = "none" },
						StatusLineNC = { bg = "none" },

						-- floats / popups / menus
						NormalFloat = { bg = "none" },
						FloatBorder = { bg = "none" },
						Pmenu = { bg = "none" },
						PmenuSel = { bg = "none" },
					}
				end,
				theme = "dragon", -- Load "wave" theme
				background = { -- map the value of 'background' option to a theme
					dark = "dragon", -- try "dragon" !
					light = "lotus",
				},
			})
			-- vim.cmd("colorscheme kanagawa")
		end,
	},
}
