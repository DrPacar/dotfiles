-- ==========================================================================
-- Tokyo Night Theme & Statusline
-- ==========================================================================

-- Tokyo Night Colorscheme
local tokyonight_ok, tokyonight = pcall(require, "tokyonight")
if tokyonight_ok then
  tokyonight.setup({
    style = "night",
    transparent = false,
    styles = {
      comments = { italic = true },
      keywords = { italic = true },
      functions = {},
      variables = {},
      sidebars = "dark",
      floats = "dark",
    },
  })
  vim.cmd.colorscheme("tokyonight")
end

-- Mini Icons
local mini_icons_ok, mini_icons = pcall(require, "mini.icons")
if mini_icons_ok then
  mini_icons.setup()
end

-- Lualine Statusline
local lualine_ok, lualine = pcall(require, "lualine")
if lualine_ok then
  lualine.setup({
    options = {
      theme = "tokyonight",
      globalstatus = true,
      component_separators = { left = "", right = "" },
      section_separators = { left = "", right = "" },
      disabled_filetypes = { statusline = { "yazi" } },
    },
    sections = {
      lualine_a = { "mode" },
      lualine_b = { "branch", "diff", "diagnostics" },
      lualine_c = { { "filename", path = 1 } },
      lualine_x = { "encoding", "fileformat", "filetype" },
      lualine_y = { "progress" },
      lualine_z = { "location" },
    },
  })
end
