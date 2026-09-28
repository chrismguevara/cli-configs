return {
  "stevearc/oil.nvim",
  lazy = false,
  keys = {
    { "-", "<cmd>Oil<CR>", desc = "Open parent directory (Oil)" },
  },
  opts = {
    default_file_explorer = true,
    view_options = { show_hidden = true },
    skip_confirm_for_simple_edits = true,
    keymaps = {
      ["q"] = "actions.close",
      -- keep Ctrl-h/j/k/l for window navigation
      ["<C-h>"] = false,
      ["<C-l>"] = false,
    },
  },
}
