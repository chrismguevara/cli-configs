-- Language servers via the native Neovim API (vim.lsp.config / vim.lsp.enable).
-- nvim-lspconfig only contributes the default definitions in its lsp/ directory.
-- Servers are installed at the OS level (install/node.sh, install/golang.sh):
--   vtsls, vscode-eslint-language-server, vscode-html-language-server,
--   vscode-css-language-server, vscode-json-language-server, gopls

vim.diagnostic.config({
  severity_sort = true,
  float = { border = "rounded", source = "if_many" },
  virtual_text = { spacing = 2, prefix = "●" },
  signs = {
    text = {
      [vim.diagnostic.severity.ERROR] = "E",
      [vim.diagnostic.severity.WARN] = "W",
      [vim.diagnostic.severity.INFO] = "I",
      [vim.diagnostic.severity.HINT] = "H",
    },
  },
})

-- blink.cmp completion capabilities for every server.
vim.lsp.config("*", {
  capabilities = require("blink.cmp").get_lsp_capabilities(),
})

-- TypeScript / JavaScript: vtsls (wraps the VS Code TypeScript extension).
-- Monorepo: lspconfig picks the nearest lock file as root and vtsls resolves the
-- package's own tsconfig. autoUseWorkspaceTsdk makes it use that package's
-- node_modules/typescript instead of the globally installed one.
vim.lsp.config("vtsls", {
  settings = {
    vtsls = {
      autoUseWorkspaceTsdk = true,
      experimental = { completion = { enableServerSideFuzzyMatch = true } },
    },
    typescript = {
      updateImportsOnFileMove = { enabled = "always" },
      suggest = { completeFunctionCalls = true },
      inlayHints = {
        parameterNames = { enabled = "literals" },
        variableTypes = { enabled = false },
        functionLikeReturnTypes = { enabled = true },
      },
    },
    javascript = {
      updateImportsOnFileMove = { enabled = "always" },
    },
  },
})

-- ESLint: uses the project's own eslint (node_modules) and flat config.
vim.lsp.config("eslint", {
  settings = {
    workingDirectories = { mode = "auto" },
  },
})

-- Go: gopls with staticcheck analyzers; formatting is done by conform (goimports/gofmt).
vim.lsp.config("gopls", {
  settings = {
    gopls = {
      staticcheck = true,
      gofumpt = false,
      usePlaceholders = true,
      analyses = { unusedparams = true, shadow = false },
      hints = { parameterNames = true },
    },
  },
})

vim.lsp.config("jsonls", {
  settings = { json = { validate = { enable = true } } },
})

vim.lsp.enable({ "vtsls", "eslint", "gopls", "html", "cssls", "jsonls" })

-- Buffer-local mappings once a server attaches.
vim.api.nvim_create_autocmd("LspAttach", {
  group = vim.api.nvim_create_augroup("dev-lsp-attach", { clear = true }),
  callback = function(ev)
    local client = vim.lsp.get_client_by_id(ev.data.client_id)
    local function bmap(mode, lhs, rhs, desc)
      vim.keymap.set(mode, lhs, rhs, { buffer = ev.buf, desc = desc })
    end
    local tb = require("telescope.builtin")
    bmap("n", "gd", tb.lsp_definitions, "Goto definition")
    bmap("n", "gr", tb.lsp_references, "References")
    bmap("n", "gI", tb.lsp_implementations, "Goto implementation")
    bmap("n", "gy", tb.lsp_type_definitions, "Goto type definition")
    bmap("n", "gD", vim.lsp.buf.declaration, "Goto declaration")
    bmap("n", "K", vim.lsp.buf.hover, "Hover")
    bmap("n", "<leader>rn", vim.lsp.buf.rename, "Rename symbol")
    bmap({ "n", "v" }, "<leader>ca", vim.lsp.buf.code_action, "Code action")
    bmap("n", "<leader>ds", tb.lsp_document_symbols, "Document symbols")
    bmap("n", "<leader>ws", tb.lsp_dynamic_workspace_symbols, "Workspace symbols")

    if client and client:supports_method("textDocument/inlayHint") then
      bmap("n", "<leader>th", function()
        vim.lsp.inlay_hint.enable(not vim.lsp.inlay_hint.is_enabled({ bufnr = ev.buf }), { bufnr = ev.buf })
      end, "Toggle inlay hints")
    end
  end,
})
