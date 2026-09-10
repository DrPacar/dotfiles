{...}: {
  programs.noctalia = {
    enable = true;

    settings = {
      shell = {
        font_family = "JetBrainsMono Nerd Font";
      };

      theme = {
        mode = "dark";
        source = "builtin";
        builtin = "Tokyo-Night";
      };

      wallpaper = {
        # Hyprpaper manages desktop wallpaper
        enabled = false;
      };

      bar.main = {
        position = "top";
        start = ["launcher" "workspaces" "active-window"];
        center = ["clock"];
        end = [
          "media"
          "tray"
          "notifications"
          "clipboard"
          "network"
          "volume"
          "brightness"
          "battery"
          "control-center"
          "session"
        ];
      };
    };
  };
}
