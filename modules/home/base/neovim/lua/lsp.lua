-- ==========================================================================
-- LSP Configuration & Document Tools (Neovim 0.11+ native vim.lsp.config)
-- ==========================================================================

-- Diagnostic display configuration
vim.diagnostic.config({
  virtual_text = {
    prefix = "●",
  },
  signs = {
    text = {
      [vim.diagnostic.severity.ERROR] = " ",
      [vim.diagnostic.severity.WARN] = " ",
      [vim.diagnostic.severity.HINT] = " ",
      [vim.diagnostic.severity.INFO] = " ",
    },
  },
  underline = true,
  update_in_insert = false,
  severity_sort = true,
  float = {
    border = "rounded",
    source = "always",
  },
})

-- Capabilities (Blink.cmp integration)
local capabilities = vim.lsp.protocol.make_client_capabilities()
local blink_ok, blink = pcall(require, "blink.cmp")
if blink_ok then
  capabilities = blink.get_lsp_capabilities(capabilities)
end

-- Global client capabilities
vim.lsp.config("*", {
  capabilities = capabilities,
})

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

-- LSP Server Configurations

-- Nix LSP (nil)
vim.lsp.config("nil_ls", {
  settings = {
    ["nil"] = {
      formatting = {
        command = { "nixfmt" },
      },
    },
  },
})

-- Typst LSP (tinymist)
vim.lsp.config("tinymist", {
  settings = {
    exportPdf = "never",
  },
})

-- LaTeX LSP (texlab)
vim.lsp.config("texlab", {
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

-- Lua LSP (lua_ls)
vim.lsp.config("lua_ls", {
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

-- Enable configured LSP servers if executable
local servers = {
  nil_ls = vim.fn.executable("nil") == 1,
  tinymist = vim.fn.executable("tinymist") == 1,
  texlab = vim.fn.executable("texlab") == 1,
  lua_ls = vim.fn.executable("lua-language-server") == 1,
  jdtls = vim.fn.executable("jdtls") == 1,
  pyright = vim.fn.executable("pyright") == 1,
  rust_analyzer = vim.fn.executable("rust-analyzer") == 1,
  gopls = vim.fn.executable("gopls") == 1,
}

for server, enabled in pairs(servers) do
  if enabled then
    vim.lsp.enable(server)
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
