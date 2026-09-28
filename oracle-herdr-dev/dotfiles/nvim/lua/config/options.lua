vim.g.mapleader = " "
vim.g.maplocalleader = " "

local o = vim.opt
o.number = true
o.relativenumber = true
o.signcolumn = "yes"
o.cursorline = true
o.termguicolors = true
o.wrap = false
o.scrolloff = 8
o.sidescrolloff = 8
o.splitright = true
o.splitbelow = true
o.ignorecase = true
o.smartcase = true
o.undofile = true
o.swapfile = false
o.updatetime = 250
o.timeoutlen = 400
o.expandtab = true
o.shiftwidth = 2
o.tabstop = 2
o.softtabstop = 2
o.smartindent = true
o.list = true
o.listchars = { tab = "» ", trail = "·", nbsp = "␣" }
o.completeopt = { "menu", "menuone", "noselect" }
o.inccommand = "split"
o.showmode = false -- lualine shows the mode
o.mouse = "a"
o.confirm = true

-- Go uses tabs (gofmt); keep width readable.
vim.api.nvim_create_autocmd("FileType", {
  pattern = { "go", "gomod", "gowork", "gosum" },
  callback = function()
    vim.bo.expandtab = false
    vim.bo.shiftwidth = 4
    vim.bo.tabstop = 4
    vim.bo.softtabstop = 4
  end,
})
