{pkgs, ...}: {
  programs.yazi = {
    enable = true;
    shellWrapperName = "y";
    enableFishIntegration = true;

    # Full set of CLI helper tools for rich in-terminal previews and Wayland integration
    extraPackages = with pkgs; [
      ffmpegthumbnailer # Video thumbnails
      poppler-utils # PDF previews (pdftoppm)
      unar # Archive preview (zip, rar, tar, etc.)
      p7zip # 7z archives
      jq # JSON formatted preview
      chafa # Image rendering fallback
      imagemagick # Image conversion & SVG
      bat # Syntax highlighted code preview
      fd # Fast file searching
      ripgrep # Fast content searching
      fzf # Fuzzy finder integration
      zoxide # Frecency directory jumping
      wl-clipboard # Wayland clipboard copy/paste
      ripdrag # Wayland drag and drop
    ];

    settings = {
      mgr = {
        ratio = [1 4 3];
        sort_by = "natural";
        sort_sensitive = false;
        sort_dir_first = true;
        linemode = "size";
        show_hidden = true;
        show_symlink = true;
      };

      preview = {
        tab_size = 2;
        max_width = 1200;
        max_height = 1200;
        image_filter = "lanczos3";
        image_quality = 90;
      };

      opener = {
        edit = [
          {
            run = ''nvim "$@"'';
            block = true;
            desc = "Neovim";
          }
        ];
        open = [
          {
            run = ''xdg-open "$@"'';
            desc = "Open";
          }
        ];
        image = [
          {
            run = ''imv "$@"'';
            orphan = true;
            desc = "imv";
          }
        ];
        pdf = [
          {
            run = ''zathura "$@"'';
            orphan = true;
            desc = "Zathura";
          }
        ];
      };

      open = {
        prepend_rules = [
          {
            mime = "text/*";
            use = ["edit" "open"];
          }
          {
            mime = "image/*";
            use = ["image" "open"];
          }
          {
            mime = "application/pdf";
            use = ["pdf" "open"];
          }
        ];
      };
    };

    # TokyoNight Theme matching Ghostty, Zathura, and Neovim
    theme = {
      manager = {
        cwd = {fg = "#7dcfff";};
        hovered = {
          fg = "#1a1b26";
          bg = "#7aa2f7";
          bold = true;
        };
        preview_hovered = {underline = true;};
        find_keyword = {
          fg = "#e0af68";
          bold = true;
        };
        find_position = {
          fg = "#bb9af7";
          normal = true;
        };
        marker_copied = {
          fg = "#e0af68";
          bg = "#e0af68";
        };
        marker_cut = {
          fg = "#f7768e";
          bg = "#f7768e";
        };
        marker_marked = {
          fg = "#7dcfff";
          bg = "#7dcfff";
        };
        marker_selected = {
          fg = "#9ece6a";
          bg = "#9ece6a";
        };
        tab_active = {
          fg = "#1a1b26";
          bg = "#7aa2f7";
          bold = true;
        };
        tab_inactive = {
          fg = "#c0caf5";
          bg = "#24283b";
        };
        count_copied = {
          fg = "#1a1b26";
          bg = "#e0af68";
        };
        count_cut = {
          fg = "#1a1b26";
          bg = "#f7768e";
        };
        count_selected = {
          fg = "#1a1b26";
          bg = "#9ece6a";
        };
        border_symbol = "│";
        border_style = {fg = "#565f89";};
      };

      status = {
        separator_open = "";
        separator_close = "";
        separator_style = {
          fg = "#24283b";
          bg = "#24283b";
        };
        mode_normal = {
          fg = "#1a1b26";
          bg = "#7aa2f7";
          bold = true;
        };
        mode_select = {
          fg = "#1a1b26";
          bg = "#bb9af7";
          bold = true;
        };
        mode_unset = {
          fg = "#1a1b26";
          bg = "#f7768e";
          bold = true;
        };
        progress_label = {
          fg = "#c0caf5";
          bold = true;
        };
        progress_normal = {
          fg = "#7aa2f7";
          bg = "#24283b";
        };
        progress_error = {
          fg = "#f7768e";
          bg = "#24283b";
        };
        permissions_t = {fg = "#7aa2f7";};
        permissions_r = {fg = "#e0af68";};
        permissions_w = {fg = "#f7768e";};
        permissions_x = {fg = "#9ece6a";};
        permissions_s = {fg = "#565f89";};
      };

      select = {
        border = {fg = "#7aa2f7";};
        active = {fg = "#bb9af7";};
        inactive = {fg = "#c0caf5";};
      };

      input = {
        border = {fg = "#7aa2f7";};
        title = {fg = "#c0caf5";};
        value = {fg = "#c0caf5";};
        selected = {bg = "#24283b";};
      };

      completion = {
        border = {fg = "#7aa2f7";};
        active = {
          bg = "#24283b";
          fg = "#7aa2f7";
        };
        inactive = {fg = "#c0caf5";};
      };

      tasks = {
        border = {fg = "#7aa2f7";};
        title = {fg = "#c0caf5";};
        hovered = {underline = true;};
      };

      which = {
        mask = {bg = "#24283b";};
        cand = {fg = "#7dcfff";};
        rest = {fg = "#bb9af7";};
        desc = {fg = "#c0caf5";};
        separator = "  ";
        separator_style = {fg = "#565f89";};
      };

      help = {
        on = {fg = "#7dcfff";};
        run = {fg = "#bb9af7";};
        desc = {fg = "#c0caf5";};
        hovered = {
          bg = "#24283b";
          bold = true;
        };
        footer = {
          fg = "#c0caf5";
          bg = "#24283b";
        };
      };

      filetype = {
        rules = [
          # Images
          {
            mime = "image/*";
            fg = "#7dcfff";
          }
          # Media
          {
            mime = "video/*";
            fg = "#bb9af7";
          }
          {
            mime = "audio/*";
            fg = "#b4f9f8";
          }
          # Archives
          {
            mime = "application/*zip*";
            fg = "#f7768e";
          }
          {
            mime = "application/x-tar";
            fg = "#f7768e";
          }
          {
            mime = "application/x-bzip2";
            fg = "#f7768e";
          }
          {
            mime = "application/x-7z-compressed";
            fg = "#f7768e";
          }
          {
            mime = "application/x-rar";
            fg = "#f7768e";
          }
          # Documents
          {
            mime = "application/pdf";
            fg = "#e0af68";
          }
          # Default directory
          {
            name = "*/";
            fg = "#7aa2f7";
          }
        ];
      };
    };

    keymap = {
      mgr.prepend_keymap = [
        # Shell
        {
          on = ["!"];
          run = ''shell "$SHELL" --block --confirm'';
          desc = "Open shell here";
        }
        # Drag and drop (Wayland)
        {
          on = ["<C-n>"];
          run = "shell -- ${pkgs.ripdrag}/bin/ripdrag -x -a %s";
          desc = "Drag and drop files via ripdrag";
        }
        # Directory Navigation Jumps
        {
          on = ["g" "d"];
          run = "cd ~/dotfiles";
          desc = "Go to dotfiles";
        }
        {
          on = ["g" "u"];
          run = "cd ~/uni";
          desc = "Go to uni";
        }
        {
          on = ["g" "s"];
          run = "cd ~/data";
          desc = "Go to shared data";
        }
        {
          on = ["g" "m"];
          run = "cd /mnt/data";
          desc = "Go to /mnt/data";
        }
        {
          on = ["g" "D"];
          run = "cd ~/Downloads";
          desc = "Go to Downloads";
        }
        {
          on = ["g" "h"];
          run = "cd ~";
          desc = "Go to Home";
        }
        # Smart navigation & search plugins
        {
          on = ["z"];
          run = "plugin zoxide";
          desc = "Jump via zoxide";
        }
        {
          on = ["Z"];
          run = "plugin fzf";
          desc = "Fuzzy search via fzf";
        }
        # Clipboard shortcuts (Wayland)
        {
          on = ["y" "p"];
          run = "copy path";
          desc = "Copy absolute path";
        }
        {
          on = ["y" "d"];
          run = "copy dirname";
          desc = "Copy parent directory path";
        }
        {
          on = ["y" "f"];
          run = "copy filename";
          desc = "Copy filename";
        }
        {
          on = ["y" "n"];
          run = "copy name_without_ext";
          desc = "Copy name without extension";
        }
      ];
    };
  };

  # Enable zoxide system-wide in fish to sync jump database with yazi
  programs.zoxide = {
    enable = true;
    enableFishIntegration = true;
  };
}
