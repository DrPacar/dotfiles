{pkgs, ...}: let
  tokyonightTheme = builtins.toFile "tokyonight.rasi" ''
    * {
      bg-col: #1a1b26;
      bg-col-light: #24283b;
      border-col: #7aa2f7;
      selected-col: #3b4261;
      blue: #7aa2f7;
      fg-col: #c0caf5;
      fg-col2: #bb9af7;
      grey: #565f89;
      font: "JetBrainsMono Nerd Font 12";
    }

    element-text, element-icon, mode-switcher {
      background-color: inherit;
      text-color: inherit;
    }

    window {
      height: 480px;
      width: 680px;
      border: 2px;
      border-color: @border-col;
      background-color: @bg-col;
      border-radius: 14px;
    }

    mainbox {
      background-color: @bg-col;
      padding: 16px;
    }

    inputbar {
      children: [prompt,entry];
      background-color: @bg-col-light;
      border-radius: 8px;
      padding: 6px 12px;
      margin: 0px 0px 12px 0px;
    }

    prompt {
      background-color: transparent;
      padding: 4px;
      text-color: @blue;
      margin: 0px 6px 0px 0px;
    }

    entry {
      padding: 4px;
      margin: 0px 0px 0px 0px;
      text-color: @fg-col;
      background-color: transparent;
    }

    listview {
      border: 0px 0px 0px;
      padding: 6px 0px 0px;
      margin: 10px 0px 0px 0px;
      columns: 1;
      lines: 8;
      background-color: @bg-col;
    }

    element {
      padding: 8px 12px;
      background-color: @bg-col;
      text-color: @fg-col;
      border-radius: 8px;
    }

    element-icon {
      size: 24px;
      margin: 0px 8px 0px 0px;
    }

    element selected {
      background-color: @selected-col;
      text-color: @fg-col2;
    }

    mode-switcher {
      spacing: 0;
    }

    button {
      padding: 8px;
      background-color: @bg-col-light;
      text-color: @grey;
      vertical-align: 0.5;
      horizontal-align: 0.5;
    }

    button selected {
      background-color: @bg-col;
      text-color: @blue;
    }

    message {
      background-color: @bg-col-light;
      margin: 2px;
      padding: 2px;
      border-radius: 5px;
    }

    textbox {
      padding: 6px;
      margin: 10px;
      text-color: @blue;
      background-color: @bg-col-light;
    }
  '';

  rofiPowerMenu = pkgs.writeShellScriptBin "rofi-power-menu" ''
    chosen=$(printf "󰌾  Sperren\n󰍃  Abmelden\n󰒲  Standby\n󰜉  Neustart\n󰐥  Ausschalten" | rofi -dmenu -i -p "󰐥 Power" -theme-str '
      window {
        width: 300px;
        height: 290px;
        border: 2px;
        border-color: #7aa2f7;
        border-radius: 14px;
        background-color: #1a1b26;
      }
      mainbox {
        padding: 12px;
        background-color: #1a1b26;
      }
      inputbar {
        children: [prompt];
        background-color: #24283b;
        border-radius: 8px;
        padding: 8px 12px;
        margin: 0px 0px 8px 0px;
      }
      prompt {
        text-color: #7aa2f7;
        background-color: transparent;
      }
      listview {
        lines: 5;
        columns: 1;
        spacing: 4px;
        background-color: #1a1b26;
      }
      element {
        padding: 8px 12px;
        border-radius: 8px;
        background-color: #1a1b26;
        text-color: #c0caf5;
      }
      element selected {
        background-color: #3b4261;
        text-color: #bb9af7;
      }
    ')

    case "$chosen" in
      *"Sperren")
        hyprlock
        ;;
      *"Abmelden")
        hyprctl dispatch exit
        ;;
      *"Standby")
        systemctl suspend
        ;;
      *"Neustart")
        systemctl reboot
        ;;
      *"Ausschalten")
        systemctl poweroff
        ;;
    esac
  '';
in {
  home.packages = [
    rofiPowerMenu
  ];

  programs.rofi = {
    enable = true;
    package = pkgs.rofi;
    theme = "${tokyonightTheme}";
    extraConfig = {
      modi = "drun,run,window";
      show-icons = true;
      display-drun = " Apps";
      display-run = " Run";
      display-window = " Windows";
      drun-display-format = "{name}";
      window-format = "{w} · {c} · {t}";
    };
  };
}
