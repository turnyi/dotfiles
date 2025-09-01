return {
	"hrsh7th/nvim-cmp",
	dependencies = {
		"hrsh7th/cmp-nvim-lsp", -- LSP source
		"hrsh7th/cmp-buffer", -- Buffer words
		"hrsh7th/cmp-path", -- File paths
		"hrsh7th/cmp-cmdline", -- Command-line suggestions
		"L3MON4D3/LuaSnip", -- Snippet engine
		"saadparwaiz1/cmp_luasnip", -- Snippet completion
	},
	config = function()
		local cmp = require("cmp")

		cmp.setup({
			snippet = {
				expand = function(args)
					require("luasnip").lsp_expand(args.body)
				end,
			},
			window = {
				completion = cmp.config.window.bordered({
					winhighlight = "Normal:Pmenu,FloatBorder:Pmenu,Search:None",
					col_offset = 0,
					side_padding = 1,
					max_height = 5, -- Limit max items visible at a time
				}),
				documentation = cmp.config.window.bordered(),
			},
			mapping = cmp.mapping.preset.insert(require("config.keymaps").autocomplete),
			sources = cmp.config.sources({
				{ name = "nvim_lsp" }, -- LSP suggestions
				{ name = "luasnip" }, -- Snippet suggestions
				{ name = "quasar" }, -- Quasar CSS classes
				{ name = "buffer" }, -- Buffer words
				{ name = "path" }, -- File paths
			}),
			formatting = {
				format = function(entry, vim_item)
					vim_item.menu = ({
						nvim_lsp = "[LSP]",
						luasnip = "[Snippet]",
						buffer = "[Buffer]",
						path = "[Path]",
						quasar = "[Quasar]",
					})[entry.source.name]
					return vim_item
				end,
			},
			experimental = {
				ghost_text = true, -- Show ghost text before selection
			},
		})

		-- Enable command-line completion (auto-popup suggestions)
		cmp.setup.cmdline(":", {
			mapping = cmp.mapping.preset.cmdline(),
			sources = cmp.config.sources({
				{ name = "cmdline" },
				{ name = "buffer" },
			}),
		})

		-- Enable search completion (for `/` and `?`)
		cmp.setup.cmdline({ "/", "?" }, {
			mapping = cmp.mapping.preset.cmdline(),
			sources = {
				{ name = "buffer" },
			},
		})
	end,
}
