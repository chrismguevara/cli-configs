return {
  "nvim-telescope/telescope.nvim",
  cmd = "Telescope",
  dependencies = {
    "nvim-lua/plenary.nvim",
    -- Native fzf sorter, compiled with make/gcc from install/base.sh.
    { "nvim-telescope/telescope-fzf-native.nvim", build = "make" },
  },
  keys = {
    { "<leader>ff", function() require("telescope.builtin").find_files() end, desc = "Find files" },
    { "<leader>fg", function() require("telescope.builtin").live_grep() end, desc = "Live grep" },
    { "<leader>fb", function() require("telescope.builtin").buffers() end, desc = "Buffers" },
    { "<leader>fh", function() require("telescope.builtin").help_tags() end, desc = "Help tags" },
    { "<leader>fr", function() require("telescope.builtin").oldfiles() end, desc = "Recent files" },
    { "<leader>fd", function() require("telescope.builtin").diagnostics() end, desc = "Diagnostics" },
    { "<leader>fs", function() require("telescope.builtin").grep_string() end, desc = "Grep word under cursor" },
    { "<leader>/", function() require("telescope.builtin").current_buffer_fuzzy_find() end, desc = "Search in buffer" },
  },
  opts = {
    defaults = {
      path_display = { "truncate" },
      sorting_strategy = "ascending",
      layout_config = { prompt_position = "top" },
      file_ignore_patterns = { "^%.git/", "node_modules/", "^dist/" },
    },
    pickers = {
      find_files = { hidden = true },
    },
  },
  config = function(_, opts)
    local telescope = require("telescope")
    telescope.setup(opts)
    telescope.load_extension("fzf")
  end,
}
