return {
	{
		"catppuccin/nvim",
		name = "catppuccin",
		priority = 1000, -- load before other UI plugins
		lazy = false, -- colorscheme should load at startup
		init = function()
			-- latte, frappe, macchiato, mocha
			vim.g.catppuccin_flavour = "frappe"
		end,
		opts = {
			-- See big comment in integrations.virtual_text below
			no_italic = true,
			transparent_background = true,
			float = {
				transparent = false, -- enable transparent floating windows
				solid = true, -- use solid styling for floating windows, see |winborder|
			},

			styles = {
				comments = {},
				conditionals = {},
				loops = {},
				functions = {},
				keywords = {},
				strings = {},
				variables = {},
				numbers = {},
				booleans = {},
				properties = {},
				types = {},
				operators = {},
			},
			integrations = {
				treesitter = true,
				native_lsp = {
					enabled = true,
					-- TL;DR: these italic specs don't apply because no_italic=true.
					-- You re-apply italics manually below with :hi commands.
					virtual_text = {
						errors = { "italic" },
						hints = { "italic" },
						warnings = { "italic" },
						information = { "italic" },
					},
					underlines = {
						errors = { "underline" },
						hints = { "underline" },
						warnings = { "underline" },
						information = { "underline" },
					},
				},
				cmp = true,
				telescope = true,
				nvimtree = false,
			},
			custom_highlights = function(colors)
				local t = {
					CursorLine = { bg = "#3a3b3c" },
					ColorColumn = { bg = "#4e4e4e" },
					TabLineFill = { bg = "#bbc2cf", fg = "black" },
					WinSeparator = { fg = colors.surface1, bg = "NONE" },
					Visual = { bg = "#61677d", style = { "bold" } },
					HighlightOnYank = { bg = "#71778d" },

					CursorLineNr = { fg = "#e2e209" },
					SignColumn = { fg = "#a8a8a8" },
					LineNr = { fg = "#8a8a8a" },
					Comment = { fg = "#aaaaaa" },
					Todo = { fg = "#aaaaaa", bg = "none", style = { "bold" } },
					NonText = { fg = "#729ecb", style = { "bold" } },
					VertSplit = { fg = "NONE", style = { "reverse" } },
					StatusLine = { fg = "NONE", style = { "bold", "reverse" } },
					StatusLineNC = { fg = "NONE", style = { "reverse" } },
					MoreMsg = { fg = "SeaGreen", style = { "bold" } },
					MatchParen = { fg = "#87ff00", style = { "bold" } },
					CmpBorder = { fg = colors.surface2 },
					FloatBorder = { fg = "#89b4fa", bg = "none" }, -- light blue border
					NormalFloat = { bg = "none", fg = "#cdd6f4" }, -- transparent background
					-- Search       = { fg="#c6d0f5", bg="#506373" },
					-- CurSearch    = { fg="#506373", bg="#c6d0f5" },
					diffChanged = { fg = "#e5c890" },
				}
				return t
			end,
		},
		config = function(_, opts)
			require("catppuccin").setup(opts)
			vim.cmd.colorscheme("catppuccin")

			-- Your manual highlight tweaks
			vim.cmd([[
hi clear EndOfBuffer
hi link EndOfBuffer NonText
hi clear MsgSeparator
hi link MsgSeparator StatusLine
match CustomTabs /\t/
hi CustomTabs guifg=#999999 gui=NONE
match CustomTrailingWhiteSpaces /\s\+$/
hi link CustomTrailingWhiteSpaces NonText
" Setting ['@parameter'] = { style = {} } would clear
" everything else and leave it without colors
hi @parameter gui=NONE cterm=NONE
hi @namespace gui=NONE cterm=NONE

hi clear @text.uri
hi link @text.uri @comment
hi @text.uri gui=ITALIC cterm=ITALIC
hi clear @string.special.url
hi link @string.special.url @text.uri

hi clear @module
hi link @module Type

hi clear @comment.todo
hi clear @comment.error
hi clear @comment.warning
hi clear @comment.hint
hi clear @comment.note
hi @comment.todo    gui=BOLD
hi @comment.error   gui=BOLD
hi @comment.warning gui=BOLD
hi @comment.hint    gui=BOLD
hi @comment.note    gui=BOLD

" One day I woke up and go files looked like shit.
" Function call likes "fmt.Println" and builtins like "make"
" all had the same color as numbers, orange, and types are yellow.
" Everything looked like shit. They used to be blue, just like
" function declarations. So that's why I linked them to @function.
hi clear @method.call
hi link @method.call @function

hi clear @module
hi link @module Type

hi Folded guibg=#101010

hi DiagnosticVirtualTextError gui=ITALIC cterm=ITALIC
hi DiagnosticVirtualTextHint  gui=ITALIC cterm=ITALIC
hi DiagnosticVirtualTextInfo  gui=ITALIC cterm=ITALIC
hi DiagnosticVirtualTextOk    gui=ITALIC cterm=ITALIC
hi DiagnosticVirtualTextWarn  gui=ITALIC cterm=ITALIC
]])
		end,
	},
}
