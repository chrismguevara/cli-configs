-- Official nvim-treesitter, main branch (Neovim >= 0.12, tree-sitter CLI >= 0.26.1).
-- Parsers are compiled locally with the C compiler + tree-sitter CLI from install/,
-- by bin/nvim-bootstrap (run from bin/install-dotfiles), which reads this list.
-- Nothing is installed at startup on purpose: five panes starting at once would
-- race while compiling into the same directory. Add a language here, then run
-- `nvim-bootstrap` (or :TSInstall <lang>).
local languages = {
  -- TypeScript / web
  "typescript", "tsx", "javascript", "jsdoc", "json", "css", "html",
  -- Go
  "go", "gomod", "gosum", "gowork",
  -- editor / config
  "lua", "luadoc", "vim", "vimdoc", "query", "bash", "toml", "yaml",
  "markdown", "markdown_inline", "diff", "gitcommit", "git_rebase", "regex",
}

return {
  "nvim-treesitter/nvim-treesitter",
  branch = "main",
  lazy = false,
  build = ":TSUpdate",
  config = function()
    require("nvim-treesitter").setup({
      install_dir = vim.fn.stdpath("data") .. "/site",
    })
    vim.api.nvim_create_autocmd("FileType", {
      group = vim.api.nvim_create_augroup("dev-treesitter", { clear = true }),
      callback = function(ev)
        local lang = vim.treesitter.language.get_lang(ev.match) or ev.match
        if not vim.treesitter.language.add(lang) then
          return -- no parser (yet): fall back to regex highlighting
        end
        vim.treesitter.start(ev.buf, lang)
        vim.bo[ev.buf].indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
      end,
    })
  end,
}
