-- ==========================================================================
-- Plugins Configuration
-- ==========================================================================

-- 1. Yazi File Manager Integration
local yazi_ok, yazi = pcall(require, "yazi")
if yazi_ok then
  yazi.setup({
    open_for_directories = false,
    floating_window_scaling_factor = 0.9,
    yazi_floating_window_winblend = 0,
  })
  vim.keymap.set("n", "<leader>e", function()
    yazi.yazi()
  end, { desc = "Open Yazi (Current File)" })
  vim.keymap.set("n", "<leader>cw", function()
    yazi.yazi(nil, vim.fn.getcwd())
  end, { desc = "Open Yazi (Working Directory)" })
end

-- 2. Telescope Fuzzy Finder
local telescope_ok, telescope = pcall(require, "telescope")
if telescope_ok then
  local builtin = require("telescope.builtin")
  telescope.setup({
    defaults = {
      prompt_prefix = "   ",
      selection_caret = "  ",
      path_display = { "truncate" },
    },
  })
  pcall(telescope.load_extension, "fzf")

  vim.keymap.set("n", "<leader>ff", builtin.find_files, { desc = "Find Files" })
  vim.keymap.set("n", "<leader>fg", builtin.live_grep, { desc = "Live Grep" })
  vim.keymap.set("n", "<leader>fb", builtin.buffers, { desc = "Find Buffers" })
  vim.keymap.set("n", "<leader>fh", builtin.help_tags, { desc = "Help Tags" })
  vim.keymap.set("n", "<leader>fr", builtin.oldfiles, { desc = "Recent Files" })
end

-- 3. Gitsigns (Git status, hunks, blame)
local gitsigns_ok, gitsigns = pcall(require, "gitsigns")
if gitsigns_ok then
  gitsigns.setup({
    signs = {
      add = { text = "▎" },
      change = { text = "▎" },
      delete = { text = "" },
      topdelete = { text = "‾" },
      changedelete = { text = "▎" },
    },
    on_attach = function(bufnr)
      local gs = package.loaded.gitsigns
      vim.keymap.set("n", "]h", gs.next_hunk, { buffer = bufnr, desc = "Next Git Hunk" })
      vim.keymap.set("n", "[h", gs.prev_hunk, { buffer = bufnr, desc = "Prev Git Hunk" })
      vim.keymap.set("n", "<leader>hp", gs.preview_hunk, { buffer = bufnr, desc = "Preview Git Hunk" })
      vim.keymap.set("n", "<leader>hs", gs.stage_hunk, { buffer = bufnr, desc = "Stage Git Hunk" })
      vim.keymap.set("n", "<leader>hr", gs.reset_hunk, { buffer = bufnr, desc = "Reset Git Hunk" })
      vim.keymap.set("n", "<leader>hb", function()
        gs.blame_line({ full = true })
      end, { buffer = bufnr, desc = "Git Blame Line" })
    end,
  })
end

-- 4. Mini Plugins (Pairs, Surround, Comment)
pcall(function()
  require("mini.pairs").setup()
end)
pcall(function()
  require("mini.surround").setup()
end)
pcall(function()
  require("mini.comment").setup()
end)

-- 5. Blink.cmp (Blazing fast Auto-Completion)
local blink_ok, blink = pcall(require, "blink.cmp")
if blink_ok then
  blink.setup({
    keymap = { preset = "default" },
    appearance = {
      use_nvim_cmp_as_default = true,
      nerd_font_variant = "mono",
    },
    sources = {
      default = { "lsp", "path", "snippets", "buffer" },
    },
    completion = {
      documentation = { auto_show = true, auto_show_delay_ms = 200 },
      ghost_text = { enabled = true },
    },
  })
end

-- 6. Conform.nvim (Formatting on Save)
local conform_ok, conform = pcall(require, "conform")
if conform_ok then
  conform.setup({
    formatters_by_ft = {
      nix = { "nixfmt" },
      typst = { "typstyle" },
      lua = { "stylua" },
      java = { "google-java-format" },
      python = { "isort", "black" },
      rust = { "rustfmt" },
    },
    format_on_save = {
      timeout_ms = 800,
      lsp_fallback = true,
    },
  })
  vim.keymap.set({ "n", "v" }, "<leader>cf", function()
    conform.format({ async = false, timeout_ms = 800, lsp_fallback = true })
  end, { desc = "Format Document" })
end

-- 7. Which-Key (Keybinding Hints)
local wk_ok, wk = pcall(require, "which-key")
if wk_ok then
  wk.setup()
  wk.add({
    { "<leader>f", group = "Find (Telescope)" },
    { "<leader>s", group = "Splits" },
    { "<leader>b", group = "Buffers" },
    { "<leader>h", group = "Git Hunks" },
    { "<leader>c", group = "Code / LSP" },
  })
end
