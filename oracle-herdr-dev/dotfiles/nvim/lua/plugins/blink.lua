return {
  "saghen/blink.cmp",
  version = "1.*", -- pinned release: uses the prebuilt fuzzy-matcher binary
  event = "InsertEnter",
  opts = {
    keymap = { preset = "default" }, -- <C-space> menu, <C-y> accept, <C-n>/<C-p> move
    appearance = { nerd_font_variant = "mono" },
    completion = {
      documentation = { auto_show = true, auto_show_delay_ms = 200 },
      list = { selection = { preselect = true, auto_insert = false } },
    },
    signature = { enabled = true },
    sources = { default = { "lsp", "path", "snippets", "buffer" } },
    fuzzy = { implementation = "prefer_rust_with_warning" },
  },
  opts_extend = { "sources.default" },
}
