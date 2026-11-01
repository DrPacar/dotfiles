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
