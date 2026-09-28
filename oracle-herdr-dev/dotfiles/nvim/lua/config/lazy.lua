-- Bootstrap lazy.nvim (stable branch) into the data directory, then load every
-- spec in lua/plugins/. Plugin versions are pinned by lazy-lock.json (committed).
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not (vim.uv or vim.loop).fs_stat(lazypath) then
  local out = vim.fn.system({
    "git", "clone", "--filter=blob:none", "--branch=stable",
    "https://github.com/folke/lazy.nvim.git", lazypath,
  })
  if vim.v.shell_error ~= 0 then
    error("Failed to clone lazy.nvim:\n" .. out)
  end
end
vim.opt.rtp:prepend(lazypath)

require("lazy").setup({
  spec = { { import = "plugins" } },
  install = { colorscheme = { "catppuccin", "default" } },
  -- Upgrades are deliberate (:Lazy update), never automatic.
  checker = { enabled = false },
  change_detection = { notify = false },
  rocks = { enabled = false },
  performance = {
    rtp = { disabled_plugins = { "gzip", "tarPlugin", "tohtml", "tutor", "zipPlugin" } },
  },
})
