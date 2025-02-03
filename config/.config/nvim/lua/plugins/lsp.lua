return {
    {
        "williamboman/mason.nvim",
        config = function()
            require("mason").setup()
        end,
    },
    {
        "williamboman/mason-lspconfig.nvim",
        dependencies = { "williamboman/mason.nvim", "neovim/nvim-lspconfig" },
        config = function()
            local servers = {
                "lua_ls",
                "ts_ls",
                "html",
                "cssls",
                "eslint",
                "jsonls",
                "bashls",
                "pyright",
                "clangd",
                "omnisharp",
                "vuels",
                "volar",
                "emmet_ls",
            }

            -- Ensure servers are installed via Mason
            require("mason-lspconfig").setup {
                ensure_installed = servers,
            }

            -- Set up LSP servers with lspconfig
            local lspconfig = require("lspconfig")
            for _, server in ipairs(servers) do
                lspconfig[server].setup({})
            end
        end,
    },
    { "neovim/nvim-lspconfig" },
}
