{pkgs, ...}: {
  programs.ghostty = {
    enable = true;
    settings = {
      # Theme & Appearance
      theme = "TokyoNight";
      background-opacity = 0.92;
      background-blur-radius = 20;

      # Typography & Ligatures
      font-family = "JetBrainsMono Nerd Font";
      font-size = 13;
      font-feature = [
        "calt"
        "liga"
        "dlig"
        "zero"
      ];

      # Window & Hyprland Integration
      window-decoration = false;
      gtk-titlebar = false;
      window-theme = "dark";
      window-padding-x = 12;
      window-padding-y = 10;
      window-padding-balance = true;

      # Mouse & Cursor Behavior
      cursor-style = "block";
      cursor-style-blink = false;
      cursor-click-to-move = true;
      mouse-hide-while-typing = true;

      # Clipboard & Selection
      copy-on-select = "clipboard";
      clipboard-read = "allow";
      clipboard-paste-protection = true;
      clipboard-trim-trailing-spaces = true;

      # Splits & Focus
      unfocused-split-opacity = 0.8;

      # Shell Integration & Long-running command notifications
      shell-integration = "detect";
      notify-on-command-finish = "unfocused";
      notify-on-command-finish-action = "notify";
      notify-on-command-finish-after = "10s";

      # Window & Process Lifecycle
      confirm-close-surface = false;
      quit-after-last-window-closed = true;
    };
  };
}
