-- ==========================================================================
-- LSP Configuration & Document Tools
-- ==========================================================================

-- Diagnostic display configuration
vim.diagnostic.config({
  virtual_text = {
    prefix = "●",
  },
  signs = true,
  underline = true,
  update_in_insert = false,
  severity_sort = true,
  float = {
    border = "rounded",
    source = "always",
  },
})

-- Diagnostic signs
local signs = { Error = " ", Warn = " ", Hint = " ", Info = " " }
for type, icon in pairs(signs) do
  local hl = "DiagnosticSign" .. type
  vim.fn.sign_define(hl, { text = icon, texthl = hl, numhl = "" })
end

-- Capabilities (Blink.cmp integration)
local capabilities = vim.lsp.protocol.make_client_capabilities()
local blink_ok, blink = pcall(require, "blink.cmp")
if blink_ok then
  capabilities = blink.get_lsp_capabilities(capabilities)
end

-- Global LSP Attach Autocmd (Keymaps)
vim.api.nvim_create_autocmd("LspAttach", {
  group = vim.api.nvim_create_augroup("UserLspConfig", { clear = true }),
  callback = function(ev)
    local map = function(keys, func, desc)
      vim.keymap.set("n", keys, func, { buffer = ev.buf, desc = desc })
    end

    map("gd", vim.lsp.buf.definition, "Go to Definition")
    map("gD", vim.lsp.buf.declaration, "Go to Declaration")
    map("gi", vim.lsp.buf.implementation, "Go to Implementation")
    map("gr", "<cmd>Telescope lsp_references<CR>", "LSP References")
    map("K", vim.lsp.buf.hover, "Hover Documentation")
    map("<leader>cr", vim.lsp.buf.rename, "Rename Symbol")
    map("<leader>ca", vim.lsp.buf.code_action, "Code Action")
    map("<leader>cd", vim.diagnostic.open_float, "Line Diagnostics")
    map("[d", vim.diagnostic.goto_prev, "Previous Diagnostic")
    map("]d", vim.diagnostic.goto_next, "Next Diagnostic")
  end,
})

-- VimTeX configuration (preserved & optimized)
vim.g.vimtex_view_method = "zathura"
vim.g.vimtex_compiler_method = "latexmk"
vim.g.vimtex_quickfix_mode = 0

-- LSP Servers Setup via nvim-lspconfig
local lspconfig_ok, lspconfig = pcall(require, "lspconfig")
if lspconfig_ok then
  -- Nix LSP (nil)
  if vim.fn.executable("nil") == 1 then
    lspconfig.nil_ls.setup({
      capabilities = capabilities,
      settings = {
        ["nil"] = {
          formatting = {
            command = { "nixfmt" },
          },
        },
      },
    })
  end

  -- Typst LSP (tinymist)
  if vim.fn.executable("tinymist") == 1 then
    lspconfig.tinymist.setup({
      capabilities = capabilities,
      settings = {
        exportPdf = "never",
      },
    })
  end

  -- LaTeX LSP (texlab)
  if vim.fn.executable("texlab") == 1 then
    lspconfig.texlab.setup({
      capabilities = capabilities,
      settings = {
        texlab = {
          build = {
            executable = "latexmk",
            args = { "-pdf", "-interaction=nonstopmode", "-synctex=1", "%f" },
            onSave = false, -- Handled continuously by VimTeX
          },
        },
      },
    })
  end

  -- Lua LSP (lua_ls)
  if vim.fn.executable("lua-language-server") == 1 then
    lspconfig.lua_ls.setup({
      capabilities = capabilities,
      settings = {
        Lua = {
          diagnostics = {
            globals = { "vim" },
          },
          workspace = {
            checkThirdParty = false,
            library = vim.api.nvim_get_runtime_file("", true),
          },
          telemetry = { enable = false },
        },
      },
    })
  end

  -- Python LSP (pyright)
  if vim.fn.executable("pyright") == 1 then
    lspconfig.pyright.setup({ capabilities = capabilities })
  end

  -- Rust LSP (rust_analyzer)
  if vim.fn.executable("rust-analyzer") == 1 then
    lspconfig.rust_analyzer.setup({ capabilities = capabilities })
  end

  -- Go LSP (gopls)
  if vim.fn.executable("gopls") == 1 then
    lspconfig.gopls.setup({ capabilities = capabilities })
  end
end

-- FileType specific options
vim.api.nvim_create_autocmd("FileType", {
  pattern = { "typst", "tex", "plaintex", "bib", "markdown" },
  callback = function()
    vim.opt_local.wrap = true
    vim.opt_local.spell = true
  end,
})
