-- Formatting. JS/TS/JSON/CSS: the project's own node_modules/.bin/oxfmt, never a
-- global oxfmt and never LSP formatting. Go: goimports, falling back to gofmt.

-- Like conform's built-in from_node_modules(), but with no PATH fallback: if the
-- project has no oxfmt, formatting fails loudly instead of using something else.
local function project_oxfmt(_, ctx)
  local found = vim.fs.find("node_modules/.bin/oxfmt", { upward = true, path = ctx.dirname, type = "file" })[1]
  if found then
    return found
  end
  vim.notify(
    "conform: no node_modules/.bin/oxfmt above " .. ctx.dirname .. " (pnpm add -D oxfmt)",
    vim.log.levels.ERROR
  )
  return "oxfmt-missing-from-project" -- not executable -> conform reports the formatter as unavailable
end

local web = { "oxfmt" }

return {
  "stevearc/conform.nvim",
  event = { "BufWritePre" },
  cmd = { "ConformInfo" },
  keys = {
    {
      "<leader>cf",
      function() require("conform").format({ async = true }) end,
      mode = { "n", "v" },
      desc = "Format buffer (oxfmt / goimports)",
    },
  },
  opts = function()
    -- conform.util is only available once the plugin is loaded, hence a function.
    local util = require("conform.util")
    return {
    formatters_by_ft = {
      javascript = web,
      javascriptreact = web,
      typescript = web,
      typescriptreact = web,
      json = web,
      jsonc = web,
      css = web,
      go = { "goimports", "gofmt", stop_after_first = true },
    },
    -- Never fall back to LSP formatting: if oxfmt/goimports are missing you see an error.
    default_format_opts = { lsp_format = "never", timeout_ms = 5000 },
    formatters = {
      oxfmt = {
        command = project_oxfmt,
        args = { "--stdin-filepath", "$FILENAME" },
        stdin = true,
        cwd = util.root_file({ ".oxfmtrc.json", ".oxfmtrc.jsonc", "package.json" }),
      },
    },
    format_on_save = function()
      if not vim.g.format_on_save then
        return nil
      end
      return { timeout_ms = 5000, lsp_format = "never" }
    end,
    }
  end,
}
