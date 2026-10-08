{
  lib,
  osConfig,
  ...
}: let
  hasBattery = osConfig.device.hasBattery or false;
in {
  programs.noctalia = {
    enable = true;

    settings = {
      shell = {
        font_family = "JetBrainsMono Nerd Font";
        screenshot = {
          directory = "~/Pictures/Screenshots";
          copy_to_clipboard = true;
          save_to_file = true;
          freeze_screen = true;
          close_on_copy = true;
        };
      };

      theme = {
        mode = "dark";
        source = "builtin";
        builtin = "Eldritch";
      };

      wallpaper = {
        enabled = true;
        fill_mode = "crop";
        default = {
          path = "${../../../../wallpapers/rest.png}";
        };
        directory = "${../../../../wallpapers}";
        automation = {
          enabled = true;
          interval_seconds = 300;
          order = "random";
        };
        transition = ["fade"];
        transition_duration = 1500.0;
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
            timeout = 600;
            action = "lock";
            enabled = true;
          };
          screen-off = {
            timeout = 660;
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

      weather = {
        enabled = true;
        unit = "metric";
      };

      bar.main = {
        position = "top";
        start = ["launcher" "workspaces" "active-window"];
        center = ["clock"];
        end =
          [
            "media"
            "tray"
            "notifications"
            "network"
            "volume"
          ]
          ++ lib.optional hasBattery "battery"
          ++ [
            "session"
          ];
      };

      widget.clock = {
        anchor = true;
      };

      widget.tray = {
        hide_passive = false;
      };
    };
  };
}
