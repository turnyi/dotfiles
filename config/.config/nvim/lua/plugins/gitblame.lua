return {
	"f-person/git-blame.nvim",
	event = "BufReadPre",
	config = function()
		vim.g.gitblame_enabled = 1 -- Disable by default (toggle manually)
		vim.g.gitblame_message_template = "<author>, <date> - <summary>"
		vim.g.gitblame_date_format = "%r" -- Relative time (e.g., "2 days ago")
	end,
}
