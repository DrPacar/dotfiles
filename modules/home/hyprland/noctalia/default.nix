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
        enabled = true;
        fill_mode = "crop";
        default = {
          path = "${../wallpapers/nature.png}";
        };
      };

      lockscreen = {
        enabled = true;
        blurred_desktop = true;
        blur_intensity = 0.5;
        tint_intensity = 0.3;
      };

      idle = {
        pre_action_fade_seconds = 5.0;
        behavior = {
          lock = {
            timeout = 300;
            action = "lock";
            enabled = true;
          };
          screen-off = {
            timeout = 360;
            action = "screen_off";
            enabled = true;
          };
          suspend = {
            timeout = 1800;
            action = "suspend";
            enabled = true;
          };
        };
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
