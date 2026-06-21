require("nvchad.configs.lspconfig").defaults()

-- Servers that work with default settings
local servers = { "html", "cssls", "pyright", "gopls" }
vim.lsp.enable(servers)

-- Lua LS: make it aware of the Neovim runtime + `vim` global
vim.lsp.config("lua_ls", {
  settings = {
    Lua = {
      diagnostics = { globals = { "vim" } },
      workspace = {
        library = {
          vim.fn.expand("$VIMRUNTIME/lua"),
          vim.fn.stdpath("data") .. "/lazy",
        },
        checkThirdParty = false,
      },
      telemetry = { enable = false },
    },
  },
})
vim.lsp.enable("lua_ls")

-- gopls: enable common analyses + staticcheck
vim.lsp.config("gopls", {
  settings = {
    gopls = {
      analyses = { unusedparams = true, shadow = true },
      staticcheck = true,
      gofumpt = true,
    },
  },
})

-- read :h vim.lsp.config for changing options of lsp servers 
