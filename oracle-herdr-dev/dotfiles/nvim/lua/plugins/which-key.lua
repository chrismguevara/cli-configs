return {
  "folke/which-key.nvim",
  event = "VeryLazy",
  opts = {
    delay = 300,
    spec = {
      { "<leader>f", group = "find" },
      { "<leader>c", group = "code" },
      { "<leader>h", group = "git hunk" },
      { "<leader>t", group = "toggle" },
      { "<leader>b", group = "buffer" },
      { "<leader>d", group = "document" },
      { "<leader>w", group = "workspace" },
      { "g", group = "goto" },
    },
  },
  keys = {
    { "<leader>?", function() require("which-key").show({ global = false }) end, desc = "Buffer keymaps" },
  },
}
