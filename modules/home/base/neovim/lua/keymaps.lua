-- ==========================================================================
-- General Keymaps
-- ==========================================================================

local map = vim.keymap.set

-- Clear search highlights on pressing Esc
map({ "i", "n" }, "<Esc>", "<cmd>nohlsearch<CR><Esc>", { desc = "Clear Search Highlights" })

-- Quick Save & Quit
map("n", "<leader>w", "<cmd>w<CR>", { desc = "Save File" })
map("n", "<leader>q", "<cmd>q<CR>", { desc = "Quit Window" })

-- Better Window Navigation (Ctrl + hjkl)
map("n", "<C-h>", "<C-w>h", { desc = "Go to Left Window" })
map("n", "<C-j>", "<C-w>j", { desc = "Go to Lower Window" })
map("n", "<C-k>", "<C-w>k", { desc = "Go to Upper Window" })
map("n", "<C-l>", "<C-w>l", { desc = "Go to Right Window" })

-- Window Splits
map("n", "<leader>sv", "<C-w>v", { desc = "Split Window Vertically" })
map("n", "<leader>sh", "<C-w>s", { desc = "Split Window Horizontally" })
map("n", "<leader>se", "<C-w>=", { desc = "Make Splits Equal Size" })
map("n", "<leader>sx", "<cmd>close<CR>", { desc = "Close Current Split" })

-- Buffer Navigation
map("n", "[b", "<cmd>bprevious<CR>", { desc = "Previous Buffer" })
map("n", "]b", "<cmd>bnext<CR>", { desc = "Next Buffer" })
map("n", "<leader>bd", "<cmd>bdelete<CR>", { desc = "Delete Buffer" })

-- Keep cursor centered during scrolling & search jumps
map("n", "<C-d>", "<C-d>zz", { desc = "Scroll Down Centered" })
map("n", "<C-u>", "<C-u>zz", { desc = "Scroll Up Centered" })
map("n", "n", "nzzzv", { desc = "Next Search Result Centered" })
map("n", "N", "Nzzzv", { desc = "Prev Search Result Centered" })

-- Move lines up/down in Visual mode
map("v", "J", ":m '>+1<CR>gv=gv", { desc = "Move Selection Down" })
map("v", "K", ":m '<-2<CR>gv=gv", { desc = "Move Selection Up" })

-- Delete & Change operations do not overwrite clipboard (black-hole register)
map({ "n", "v" }, "d", '"_d', { desc = "Delete (no clipboard overwrite)" })
map({ "n", "v" }, "D", '"_D', { desc = "Delete to end of line (no clipboard overwrite)" })
map({ "n", "v" }, "c", '"_c', { desc = "Change (no clipboard overwrite)" })
map({ "n", "v" }, "C", '"_C', { desc = "Change to end of line (no clipboard overwrite)" })
map({ "n", "v" }, "x", '"_x', { desc = "Delete char (no clipboard overwrite)" })
map({ "n", "v" }, "X", '"_X', { desc = "Delete char before (no clipboard overwrite)" })

-- Paste in visual mode without losing clipboard
map("x", "p", '"_dP', { desc = "Paste Without Overwriting Register" })
map("x", "<leader>p", '"_dP', { desc = "Paste Without Overwriting Register" })

-- Explicit Cut (saves to clipboard and deletes)
map({ "n", "v" }, "<leader>x", '"+d', { desc = "Cut to Clipboard" })
map({ "n", "v" }, "<leader>X", '"+D', { desc = "Cut to End of Line" })

-- Toggle Inlay Hints (LSP)
map("n", "<leader>th", function()
  local filter = { bufnr = 0 }
  vim.lsp.inlay_hint.enable(not vim.lsp.inlay_hint.is_enabled(filter), filter)
end, { desc = "Toggle Inlay Hints" })
