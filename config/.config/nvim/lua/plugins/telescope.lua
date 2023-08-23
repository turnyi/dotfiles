local is_telescope_installed, telescope = pcall(require, "telescope")
local is_trouble_installed, trouble = pcall(require, "trouble.providers.telescope")
local is_action_layout, action_layout = pcall(require, "telescope.actions.layout")
local fb_actions = require("telescope._extensions.file_browser.actions")
local actions = require("telescope.actions")
local state = require("telescope.actions.state")

if not is_telescope_installed then
	return
end
if not is_trouble_installed then
	return
end
if not is_action_layout then
	return
end

telescope.setup({
	defaults = {
		vimgrep_arguments = {
			"rg",
			"--color=never",
			"--no-heading",
			"--with-filename",
			"--line-number",
			"--column",
			"--smart-case",
		},
		mappings = {
			i = {
				["?"] = action_layout.toggle_preview,
				["<C-d>"] = actions.delete_buffer,
			},
			n = {
				["<C-d>"] = actions.delete_buffer,
			},
		},
		prompt_prefix = " ",
		selection_caret = " ",
		entry_prefix = "  ",
		initial_mode = "insert",
		selection_strategy = "reset",
		sorting_strategy = "ascending",
		layout_strategy = "horizontal",
		layout_config = {
			horizontal = { prompt_position = "top", preview_width = 0.55, results_width = 0.8 },
			vertical = { mirror = false },
			width = 0.87,
			height = 0.80,
			preview_cutoff = 240,
		},
		file_sorter = require("telescope.sorters").get_fuzzy_file,
		file_ignore_patterns = { "node_modules", "plugged", ".git/", "!.env" },
		generic_sorter = require("telescope.sorters").get_generic_fuzzy_sorter,
		path_display = { "truncate" },
		winblend = 0,
		-- border = {},
		-- borderchars = { "─", "│", "─", "│", "╭", "╮", "╯", "╰" },
		color_devicons = true,
		use_less = true,
		extensions = {
			fzf = {
				fuzzy = true,
				override_generic_sorter = true,
				override_file_sorter = true,
				case_mode = "smart_case",
			},
			file_browser = {
				-- path
				-- cwd
				cwd_to_path = true,
				grouped = false,
				files = true,
				add_dirs = true,
				depth = 1,
				auto_depth = false,
				select_buffer = false,
				hidden = true,
				-- respect_gitignore
				-- browse_files
				-- browse_folders
				hide_parent_dir = false,
				collapse_dirs = false,
				prompt_path = false,
				quiet = false,
				dir_icon = "",
				dir_icon_hl = "Default",
				display_stat = { date = true, size = true, mode = true },
				hijack_netrw = false,
				use_fd = true,
				git_status = true,
				mappings = {
					["i"] = {
						["<A-c>"] = fb_actions.create,
						["<S-CR>"] = fb_actions.create_from_prompt,
						["<A-r>"] = fb_actions.rename,
						["<A-m>"] = fb_actions.move,
						["<A-y>"] = fb_actions.copy,
						["<A-d>"] = fb_actions.remove,
						["<C-o>"] = fb_actions.open,
						["<C-g>"] = fb_actions.goto_parent_dir,
						["<C-e>"] = fb_actions.goto_home_dir,
						["<C-w>"] = fb_actions.goto_cwd,
						["<C-t>"] = fb_actions.change_cwd,
						["<C-f>"] = fb_actions.toggle_browser,
						["<C-h>"] = fb_actions.toggle_hidden,
						["<C-s>"] = fb_actions.toggle_all,
						["<bs>"] = fb_actions.backspace,
					},
					["n"] = {
						["c"] = fb_actions.create,
						["r"] = fb_actions.rename,
						["m"] = fb_actions.move,
						["y"] = fb_actions.copy,
						["d"] = fb_actions.remove,
						["o"] = fb_actions.open,
						["g"] = fb_actions.goto_parent_dir,
						["e"] = fb_actions.goto_home_dir,
						["w"] = fb_actions.goto_cwd,
						["t"] = fb_actions.change_cwd,
						["f"] = fb_actions.toggle_browser,
						["h"] = fb_actions.toggle_hidden,
						["s"] = fb_actions.toggle_all,
					},
				},
			},
		},
		set_env = { ["COLORTERM"] = "truecolor" }, -- default = nil,
		file_previewer = require("telescope.previewers").vim_buffer_cat.new,
		grep_previewer = require("telescope.previewers").vim_buffer_vimgrep.new,
		qflist_previewer = require("telescope.previewers").vim_buffer_qflist.new,
		-- Developer configurations: Not meant for general override
		buffer_previewer_maker = require("telescope.previewers").buffer_previewer_maker,
	},
})

local function make_relative(path1, path2)
	local function splitPath(path)
		local parts = {}
		for part in path:gmatch("[^/]+") do
			table.insert(parts, part)
		end
		return parts
	end

	local parts1 = splitPath(path1)
	local parts2 = splitPath(path2)

	-- Remove common leading parts
	while #parts1 > 0 and #parts2 > 0 and parts1[1] == parts2[1] do
		table.remove(parts1, 1)
		table.remove(parts2, 1)
	end

	-- Construct the relative path
	local relative_path = ""
	for _ = 1, #parts1 do
		relative_path = relative_path .. "../"
	end
	relative_path = relative_path .. table.concat(parts2, "/")

	if #parts1 == 0 and #parts2 == 1 then
		relative_path = "./" .. relative_path
	end

	return relative_path
end

function get_relative_path()
	local last_buffer = vim.fn.bufnr("#")
	local last_buffer_path = vim.fn.bufname(last_buffer)
	-- local root_path = vim.fn.getcwd()
	local buffer_path = vim.fn.fnamemodify(last_buffer_path, ":p:h")
	local selected_path = state.get_selected_entry().value
	local relative_path = make_relative(buffer_path, selected_path)
	vim.fn.setreg("+", relative_path)
end

-- Map the keybinding to the custom function
vim.api.nvim_set_keymap("n", "<leader>rp", ":lua get_relative_path()<CR>", { noremap = true, silent = true })

telescope.load_extension("fzf")
telescope.load_extension("zk")
telescope.load_extension("file_browser")
telescope.load_extension("live_grep_args")
return telescope
-- Telescope file_browser cwd=%:p:h
