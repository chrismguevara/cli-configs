return {
  "nvim-lualine/lualine.nvim",
  event = "VeryLazy",
  opts = {
    options = {
      theme = "auto", -- follows the active colorscheme (catppuccin)
      globalstatus = true,
      section_separators = "",
      component_separators = "|",
    },
    sections = {
      lualine_a = { "mode" },
      lualine_b = { "branch", "diff", "diagnostics" },
      lualine_c = { { "filename", path = 1 } },
      lualine_x = {
        function()
          local names = {}
          for _, c in ipairs(vim.lsp.get_clients({ bufnr = 0 })) do
            names[#names + 1] = c.name
          end
          return table.concat(names, ",")
        end,
        "filetype",
      },
      lualine_y = { "progress" },
      lualine_z = { "location" },
    },
  },
}
