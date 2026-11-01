-- ==========================================================================
-- Neovim General Options
-- ==========================================================================

-- Leader keys (Space is the gold standard)
vim.g.mapleader = " "
vim.g.maplocalleader = " "

local opt = vim.opt

-- Line numbers
opt.number = true
opt.relativenumber = true

-- Tabs & Indentation (2 spaces standard)
opt.tabstop = 2
opt.shiftwidth = 2
opt.softtabstop = 2
opt.expandtab = true
opt.smartindent = true

-- System Clipboard (Wayland integration via wl-clipboard)
opt.clipboard = "unnamedplus"

-- Appearance & Colors
opt.termguicolors = true
opt.signcolumn = "yes"
opt.cursorline = true
opt.scrolloff = 8
opt.sidescrolloff = 8

-- Search settings
opt.ignorecase = true
opt.smartcase = true
opt.hlsearch = true
opt.incsearch = true

-- Splits behavior
opt.splitright = true
opt.splitbelow = true

-- Performance & History
opt.updatetime = 250
opt.timeoutlen = 300
opt.undofile = true
opt.swapfile = false
opt.backup = false

-- Behavior
opt.wrap = false
opt.mouse = "a"
