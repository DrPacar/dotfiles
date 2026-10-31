{
  pkgs,
  inputs,
  ...
}: let
  # TokyoNight color palette (consistent with Ghostty, Zathura, Neovim)
  colors = {
    bg = "#1a1b26";
    surface = "#24283b";
    border = "#565f89";
    fg = "#c0caf5";
    blue = "#7aa2f7";
    cyan = "#7dcfff";
    purple = "#bb9af7";
    red = "#f7768e";
    yellow = "#e0af68";
    green = "#9ece6a";
    teal = "#b4f9f8";
  };

  # Shell scripts for keybindings
  scripts = {
    # Wayland Drag & Drop via ripdrag:
    ripdrag = ''shell 'set -- %s; [ $# -eq 0 ] && exit 0; if [ $# -gt 1 ]; then GTK_THEME=Adwaita:dark ripdrag -b -a -x -W 320 -H 160 "$@" 2>/dev/null & else GTK_THEME=Adwaita:dark ripdrag -b -x -W 300 -H 70 "$@" 2>/dev/null & fi' --orphan'';

    # Copy file(s) to system clipboard as text/uri-list
    copyFiles = ''shell 'for f in %s; do printf "file://%%s\r\n" "$(realpath "$f")"; done | wl-copy -t text/uri-list && notify-send -t 1500 -a "Yazi" "Clipboard" "Copied to clipboard"' --orphan'';

    # Copy raw image pixels to clipboard
    copyImage = ''shell 'wl-copy < %h && notify-send -t 1500 -a "Yazi" "Clipboard" "Copied image data to clipboard"' --orphan'';
  };

  mkJump = key: path: desc: {
    on = ["g" key];
    run = "cd ${path}";
    desc = "Go to ${desc}";
  };
in {
  programs.yazi = {
    enable = true;
    shellWrapperName = "y";
    enableFishIntegration = true;

    extraPackages = with pkgs; [
      wl-clipboard # Wayland clipboard integration
      ripdrag # Wayland drag and drop
      libnotify # Desktop notifications (notify-send)
      _7zz # 7z and archive handling
      zip # Zip compression
      unzip # Zip extraction
      poppler-utils # PDF previews (pdftoppm)
      imagemagick # SVG & image conversions
      chafa # Character-art image preview fallback
      jq # JSON format previews
      mpv # Video and audio player
      udisks2 # Mount manager daemon client
      util-linux # lsblk and eject for mount manager
      ripgrep # Content search (yafg)
      fzf # Fuzzy finder (yafg)
      bat # Syntax highlighting preview (yafg)
    ];

    # Community plugins packaged in Nixpkgs
    plugins = {
      smart-enter = {
        package = pkgs.yaziPlugins.smart-enter;
      };
      chmod = {
        package = pkgs.yaziPlugins.chmod;
      };
      git = {
        package = pkgs.yaziPlugins.git;
        setup = true;
      };
      compress = {
        package = inputs.compress-yazi;
      };
      mount = {
        package = pkgs.yaziPlugins.mount;
      };
      yafg = {
        package = pkgs.yaziPlugins.yafg;
        setup = true;
        settings = {
          editor = "nvim";
          file_arg_format = "+{row} {file}";
        };
      };
    };

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
            run = ''command -v nvim >/dev/null && nvim %s || ''${EDITOR:-nano} %s'';
            block = true;
            desc = "Neovim";
          }
        ];
        open = [
          {
            run = "xdg-open %s";
            desc = "Open";
          }
        ];
        image = [
          {
            run = ''command -v imv >/dev/null && imv %s || xdg-open %s'';
            orphan = true;
            desc = "imv";
          }
        ];
        pdf = [
          {
            run = ''command -v zathura >/dev/null && zathura %s || xdg-open %s'';
            orphan = true;
            desc = "Zathura";
          }
        ];
        play = [
          {
            run = ''command -v mpv >/dev/null && mpv %s || xdg-open %s'';
            orphan = true;
            desc = "mpv";
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
          {
            mime = "video/*";
            use = ["play" "open"];
          }
          {
            mime = "audio/*";
            use = ["play" "open"];
          }
        ];
      };

      # Register fetchers for plugins (git status in file list)
      plugin = {
        prepend_fetchers = [
          {
            url = "*";
            run = "git";
            group = "git";
          }
          {
            url = "*/";
            run = "git";
            group = "git";
          }
        ];
      };
    };

    # TokyoNight Theme
    theme = {
      mgr = {
        cwd = {fg = colors.cyan;};
        hovered = {
          fg = colors.bg;
          bg = colors.blue;
          bold = true;
        };
        preview_hovered = {underline = true;};
        find_keyword = {
          fg = colors.yellow;
          bold = true;
        };
        find_position = {
          fg = colors.purple;
          italic = true;
        };
        marker_copied = {
          fg = colors.yellow;
          bg = colors.yellow;
        };
        marker_cut = {
          fg = colors.red;
          bg = colors.red;
        };
        marker_marked = {
          fg = colors.cyan;
          bg = colors.cyan;
        };
        marker_selected = {
          fg = colors.green;
          bg = colors.green;
        };
        count_copied = {
          fg = colors.bg;
          bg = colors.yellow;
        };
        count_cut = {
          fg = colors.bg;
          bg = colors.red;
        };
        count_selected = {
          fg = colors.bg;
          bg = colors.green;
        };
        border_symbol = "│";
        border_style = {fg = colors.border;};
      };

      tabs = {
        active = {
          fg = colors.bg;
          bg = colors.blue;
          bold = true;
        };
        inactive = {
          fg = colors.fg;
          bg = colors.surface;
        };
      };

      status = {
        sep_left = {
          open = "";
          close = "";
        };
        sep_right = {
          open = "";
          close = "";
        };
        separator_style = {
          fg = colors.surface;
          bg = colors.surface;
        };
        mode_normal = {
          fg = colors.bg;
          bg = colors.blue;
          bold = true;
        };
        mode_select = {
          fg = colors.bg;
          bg = colors.purple;
          bold = true;
        };
        mode_unset = {
          fg = colors.bg;
          bg = colors.red;
          bold = true;
        };
        progress_label = {
          fg = colors.fg;
          bold = true;
        };
        progress_normal = {
          fg = colors.blue;
          bg = colors.surface;
        };
        progress_error = {
          fg = colors.red;
          bg = colors.surface;
        };
        permissions_t = {fg = colors.blue;};
        permissions_r = {fg = colors.yellow;};
        permissions_w = {fg = colors.red;};
        permissions_x = {fg = colors.green;};
        permissions_s = {fg = colors.border;};
      };

      select = {
        border = {fg = colors.blue;};
        active = {fg = colors.purple;};
        inactive = {fg = colors.fg;};
      };

      input = {
        border = {fg = colors.blue;};
        title = {fg = colors.fg;};
        value = {fg = colors.fg;};
        selected = {bg = colors.surface;};
      };

      cmp = {
        border = {fg = colors.blue;};
        active = {
          bg = colors.surface;
          fg = colors.blue;
        };
        inactive = {fg = colors.fg;};
      };

      tasks = {
        border = {fg = colors.blue;};
        title = {fg = colors.fg;};
        hovered = {underline = true;};
      };

      which = {
        mask = {bg = colors.surface;};
        cand = {fg = colors.cyan;};
        rest = {fg = colors.purple;};
        desc = {fg = colors.fg;};
        separator = "  ";
        separator_style = {fg = colors.border;};
      };

      help = {
        on = {fg = colors.cyan;};
        run = {fg = colors.purple;};
        desc = {fg = colors.fg;};
        hovered = {
          bg = colors.surface;
          bold = true;
        };
        footer = {
          fg = colors.fg;
          bg = colors.surface;
        };
      };

      # Git status colors for git.yazi plugin
      git = {
        unknown = {fg = colors.border;};
        ignored = {fg = colors.border;};
        untracked = {fg = colors.cyan;};
        unstaged = {fg = colors.yellow;};
        staged = {fg = colors.green;};
        added = {fg = colors.green;};
        deleted = {fg = colors.red;};
        updated = {fg = colors.purple;};
        clean = {fg = colors.green;};
      };

      filetype = {
        rules =
          [
            # Images
            {
              mime = "image/*";
              fg = colors.cyan;
            }
            # Media
            {
              mime = "video/*";
              fg = colors.purple;
            }
            {
              mime = "audio/*";
              fg = colors.teal;
            }
            # Documents
            {
              mime = "application/pdf";
              fg = colors.yellow;
            }
          ]
          # Archive formats (all red)
          ++ (map (mime: {
              inherit mime;
              fg = colors.red;
            }) [
              "application/*zip*"
              "application/x-tar"
              "application/x-bzip2"
              "application/x-7z-compressed"
              "application/x-rar"
            ])
          ++ [
            # Default directory
            {
              url = "*/";
              fg = colors.blue;
            }
          ];
      };
    };

    keymap = {
      mgr.prepend_keymap =
        [
          # Shell & Terminal
          {
            on = ["!"];
            run = ''shell "$SHELL" --block'';
            desc = "Open shell here";
          }
          {
            on = ["g" "t"];
            run = ''shell 'ghostty --working-directory="$PWD" 2>/dev/null &' --orphan'';
            desc = "Open Ghostty terminal here";
          }
          # Smart enter: enter dir or open file with 'l'
          {
            on = ["l"];
            run = "plugin smart-enter";
            desc = "Enter child directory or open file";
          }
          # Permissions: chmod
          {
            on = ["c" "m"];
            run = "plugin chmod";
            desc = "Chmod on selected files";
          }
          # Archive: Compress (compress.yazi)
          {
            on = ["c" "a"];
            run = "plugin compress";
            desc = "Archive selected files";
          }
          {
            on = ["c" "z"];
            run = "plugin compress";
            desc = "Archive selected files (zip)";
          }
          {
            on = ["c" "P"];
            run = "plugin compress -p";
            desc = "Archive selected files with password";
          }
          # Archive: Extract
          {
            on = ["c" "e"];
            run = ''shell 'ya pub extract --list %s' --orphan'';
            desc = "Extract archive here";
          }
          # Mount manager (mount.yazi)
          {
            on = ["M"];
            run = "plugin mount";
            desc = "Mount manager (USB/disks)";
          }
          # Content search via ripgrep & fzf (yafg.yazi)
          {
            on = ["<C-f>"];
            run = "plugin yafg";
            desc = "Search file contents (ripgrep/fzf)";
          }
          {
            on = ["F" "G"];
            run = "plugin yafg";
            desc = "Search file contents (ripgrep/fzf)";
          }
          # Drag and drop (Wayland ripdrag)
          {
            on = ["<C-n>"];
            run = scripts.ripdrag;
            desc = "Drag and drop via ripdrag";
          }
          # Copy files to system clipboard for Ctrl+V paste in Browser / Discord
          {
            on = ["Y"];
            run = scripts.copyFiles;
            desc = "Copy files to system clipboard (Ctrl+V)";
          }
          {
            on = ["c" "u"];
            run = scripts.copyFiles;
            desc = "Copy files to system clipboard (Ctrl+V)";
          }
          # Copy raw image data to clipboard (for pasting image pixels directly into Discord/GIMP)
          {
            on = ["c" "i"];
            run = scripts.copyImage;
            desc = "Copy image data to clipboard";
          }
        ]
        # Directory Navigation Jumps (g + key)
        ++ [
          (mkJump "d" "~/dotfiles" "dotfiles")
          (mkJump "u" "~/uni" "uni")
          (mkJump "s" "~/shared" "shared folder")
          (mkJump "S" "~/data" "data")
          (mkJump "m" "/mnt/data" "/mnt/data")
          (mkJump "D" "~/Downloads" "Downloads")
          (mkJump "h" "~" "home")
        ];
    };
  };

  # Enable zoxide system-wide in fish to sync jump database with yazi
  programs.zoxide = {
    enable = true;
    enableFishIntegration = true;
  };
}
