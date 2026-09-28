-- Neovim configuration for the Oracle Linux dev VM.
-- Small on purpose: lazy.nvim + a dozen plugins, native LSP (vim.lsp.config).
-- Layout:
--   lua/config/options.lua   editor options
--   lua/config/keymaps.lua   non-plugin key mappings
--   lua/config/lazy.lua      lazy.nvim bootstrap; loads lua/plugins/*.lua
--   lua/config/lsp.lua       language servers (vtsls, eslint, gopls, html, css, json)
--   lua/config/autocmds.lua  small quality-of-life autocommands
--
-- Set to true to run conform (oxfmt / goimports) on every save.
vim.g.format_on_save = false

require("config.options")
require("config.keymaps")
require("config.lazy")
require("config.lsp")
require("config.autocmds")
