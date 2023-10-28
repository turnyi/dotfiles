local gpt = require("chatgpt")
gpt.setup({
	api_key_cmd = "echo $(OPEN_API_KEY)",
	model = "gpt-4",
})
