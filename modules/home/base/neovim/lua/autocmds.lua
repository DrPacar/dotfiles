-- ==========================================================================
-- General Autocommands (Zero-Overhead QoL)
-- ==========================================================================

local augroup = vim.api.nvim_create_augroup
local autocmd = vim.api.nvim_create_autocmd

-- 1. Highlight on Yank (Visual feedback when copying)
autocmd("TextYankPost", {
  group = augroup("HighlightYank", { clear = true }),
  desc = "Briefly highlight yanked text",
  callback = function()
    (vim.hl or vim.highlight).on_yank({ higroup = "Visual", timeout = 150 })
  end,
})

-- 2. Restore cursor position when opening a file
autocmd("BufReadPost", {
  group = augroup("RestoreCursor", { clear = true }),
  desc = "Jump to last edit position in buffer",
  callback = function(args)
    local mark = vim.api.nvim_buf_get_mark(args.buf, '"')
    local line_count = vim.api.nvim_buf_line_count(args.buf)
    if mark[1] > 0 and mark[1] <= line_count then
      pcall(vim.api.nvim_win_set_cursor, 0, mark)
    end
  end,
})

-- 3. Auto resize splits when window size changes
autocmd("VimResized", {
  group = augroup("ResizeSplits", { clear = true }),
  desc = "Auto-resize splits when window changes size",
  callback = function()
    local current_tab = vim.fn.tabpagenr()
    vim.cmd("tabdo wincmd =")
    vim.cmd("tabnext " .. current_tab)
  end,
})

-- 4. Close some utility buffers with just 'q'
autocmd("FileType", {
  group = augroup("QuickClose", { clear = true }),
  pattern = {
    "help",
    "lspinfo",
    "man",
    "notify",
    "qf",
    "query",
    "checkhealth",
  },
  callback = function(event)
    vim.bo[event.buf].buflisted = false
    vim.keymap.set("n", "q", "<cmd>close<CR>", { buffer = event.buf, silent = true, desc = "Quit Buffer" })
  end,
})
