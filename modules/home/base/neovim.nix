{pkgs, ...}: {
  programs.neovim = {
    enable = true;
    defaultEditor = true;
    viAlias = true;
    vimAlias = true;
    withRuby = false;
    withPython3 = false;

    extraPackages = with pkgs; [
      wl-clipboard # provides wl-copy and wl-paste for Wayland
    ];

    plugins = with pkgs.vimPlugins; [
      tokyonight-nvim
      typst-vim
      vimtex
    ];

    initLua = ''
      vim.opt.number = true
      vim.opt.relativenumber = true
      vim.opt.tabstop = 2
      vim.opt.shiftwidth = 2
      vim.opt.expandtab = true
      vim.opt.clipboard = "unnamedplus";

      -- Typst LSP (tinymist) & settings
      vim.api.nvim_create_autocmd("FileType", {
        pattern = "typst",
        callback = function(args)
          if vim.fn.executable("tinymist") == 1 then
            vim.lsp.start({
              name = "tinymist",
              cmd = { "tinymist" },
              root_dir = vim.fs.root(args.buf, { ".git", "typst.toml" }) or vim.fs.dirname(vim.api.nvim_buf_get_name(args.buf)),
              settings = {
                exportPdf = "never",
              },
            })
          end
          vim.opt_local.wrap = true
        end,
      })

      -- VimTeX configuration
      vim.g.vimtex_view_method = "zathura"
      vim.g.vimtex_compiler_method = "latexmk"
      vim.g.vimtex_quickfix_mode = 0

      -- LaTeX LSP (texlab) & settings
      vim.api.nvim_create_autocmd("FileType", {
        pattern = { "tex", "plaintex", "bib" },
        callback = function(args)
          if vim.fn.executable("texlab") == 1 then
            vim.lsp.start({
              name = "texlab",
              cmd = { "texlab" },
              root_dir = vim.fs.root(args.buf, { ".git", ".latexmkrc", "latexmkrc" }) or vim.fs.dirname(vim.api.nvim_buf_get_name(args.buf)),
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
          vim.opt_local.wrap = true
        end,
      })
    '';
  };
}
