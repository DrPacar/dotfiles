{pkgs, ...}: {
  xdg.configFile."nvim/lua".source = ./lua;

  programs.neovim = {
    enable = true;
    defaultEditor = true;
    viAlias = true;
    vimAlias = true;
    withRuby = false;
    withPython3 = false;

    extraPackages = with pkgs; [
      # Clipboard & Search
      wl-clipboard
      ripgrep
      fd
      fzf

      # Language Servers (LSPs)
      nil
      tinymist
      texlab
      lua-language-server
      jdt-language-server

      # Formatters
      nixfmt
      stylua
      typstyle
      google-java-format
    ];

    plugins = with pkgs.vimPlugins; [
      # Theme & UI
      tokyonight-nvim
      lualine-nvim
      which-key-nvim
      mini-nvim

      # Navigation & File management
      telescope-nvim
      telescope-fzf-native-nvim
      yazi-nvim

      # Treesitter Syntax Highlighting
      nvim-treesitter.withAllGrammars

      # Git Integration
      gitsigns-nvim

      # LSP, Completion & Formatting
      nvim-lspconfig
      blink-cmp
      conform-nvim

      # Document Tools
      typst-vim
      vimtex
    ];

    initLua = ''
      require("options")
      require("keymaps")
      require("theme")
      require("treesitter")
      require("plugins")
      require("lsp")
    '';
  };
}
