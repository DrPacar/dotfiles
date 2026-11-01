-- ==========================================================================
-- Treesitter Syntax Highlighting & Indentation
-- ==========================================================================

local ts_ok, ts = pcall(require, "nvim-treesitter.configs")
if ts_ok then
  ts.setup({
    highlight = {
      enable = true,
      additional_vim_regex_highlighting = false,
    },
    indent = {
      enable = true,
    },
  })
end

-- Sticky Headers / Code Context (nvim-treesitter-context)
local context_ok, context = pcall(require, "treesitter-context")
if context_ok then
  context.setup({
    enable = true,
    max_lines = 3,
    min_window_height = 0,
    line_numbers = true,
    multiline_threshold = 20,
    trim_scope = "outer",
    mode = "topline",
    separator = nil,
    zindex = 20,
  })

  vim.keymap.set("n", "[c", function()
    context.go_to_context(vim.v.count1)
  end, { desc = "Jump to Upper Context" })
end
