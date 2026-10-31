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
        builtin = "Tokyo-Night";
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
        blurred_desktop = false;
        blur_intensity = 0.45;
        tint_intensity = 0.25;
        transition = ["fade" "zoom"];
        transition_duration = 1000.0;
        edge_smoothness = 0.4;
        grace_period_seconds = 5;
      };

      lockscreen_widgets = {
        enabled = true;
        widget_order = [
          "clock_main"
          "clock_secondary"
          "lockscreen-login-box@DP-5"
          "lockscreen-login-box@DP-4"
        ];
        widget = {
          clock_main = {
            type = "clock";
            output = "DP-5";
            cx = 1280.0;
            cy = 480.0;
            box_width = 0.0;
            box_height = 0.0;
            settings = {
              clock_style = "digital";
              format = "{:%H:%M}";
              color = "primary";
              shadow = true;
              center_text = true;
            };
          };

          clock_secondary = {
            type = "clock";
            output = "DP-4";
            cx = 960.0;
            cy = 380.0;
            box_width = 0.0;
            box_height = 0.0;
            settings = {
              clock_style = "digital";
              format = "{:%H:%M}";
              color = "primary";
              shadow = true;
              center_text = true;
            };
          };

          "lockscreen-login-box@DP-5" = {
            type = "login_box";
            output = "DP-5";
            cx = 1280.0;
            cy = 840.0;
            box_width = 0.0;
            box_height = 0.0;
            settings = {
              layout = "regular";
              show_session_buttons = true;
              show_media = true;
              show_weather = true;
              show_unlock_hint = true;
              background_color = "surface_variant";
              background_opacity = 0.85;
              background_radius = 16.0;
              input_opacity = 0.9;
              input_radius = 8.0;
            };
          };

          "lockscreen-login-box@DP-4" = {
            type = "login_box";
            output = "DP-4";
            cx = 960.0;
            cy = 660.0;
            box_width = 0.0;
            box_height = 0.0;
            settings = {
              layout = "regular";
              show_session_buttons = true;
              show_media = true;
              show_weather = true;
              show_unlock_hint = true;
              background_color = "surface_variant";
              background_opacity = 0.85;
              background_radius = 16.0;
              input_opacity = 0.9;
              input_radius = 8.0;
            };
          };
        };
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

      location = {
        auto_locate = true;
      };

      weather = {
        enabled = true;
        unit = "metric";
      };

      bar.main = {
        position = "top";
        thickness = 36;
        background_opacity = 0.88;
        compositor_blur = true;
        radius = 16;
        concave_edge_corners = true;
        margin_edge = 0;
        margin_ends = 120;
        padding = 16;
        widget_spacing = 8;
        shadow = true;
        border = "outline";
        border_width = 1.0;

        capsule = true;
        capsule_fill = "surface_variant";
        capsule_opacity = 0.70;
        capsule_radius = 8.0;
        capsule_border = "outline";
        capsule_border_width = 1.0;
        hover_highlight = true;

        capsule_group = [
          {
            id = "sysmon";
            members = ["cpu" "ram"];
            fill = "surface_variant";
            opacity = 0.70;
            radius = 8.0;
            border = "outline";
            border_width = 1.0;
            padding = 6.0;
            widget_spacing = 6;
          }
        ];

        start = ["launcher" "workspaces" "active_window"];
        center = ["clock"];
        end =
          [
            "privacy"
            "group:sysmon"
            "power_profile"
            "caffeine"
            "nightlight"
            "brightness"
            "volume"
            "network"
            "weather"
            "tray"
          ]
          ++ lib.optional hasBattery "battery"
          ++ [
            "session"
          ];
      };

      widget.launcher = {
        glyph = "U+F313";
        icon_color = "primary";
      };

      widget.workspaces = {
        style = "minimal";
        show_labels = true;
        label_source = "id";
        focused_color = "primary";
        occupied_color = "secondary";
        empty_color = "outline";
        change_color_on_hover = true;
      };

      widget.active_window = {
        min_length = 50;
        max_length = 240;
        title_scroll = "on_hover";
        show_empty_label = false;
      };

      widget.clock = {
        anchor = true;
        format = "{:%H:%M}  •  {:%a, %d. %b}";
        tooltip_format = "{:%A, %d. %B %Y}";
        font_weight = 600;
      };

      widget.privacy = {
        hide_inactive = true;
      };

      widget.cpu = {
        type = "sysmon";
        stat = "cpu_usage";
        visualization = "none";
      };

      widget.ram = {
        type = "sysmon";
        stat = "ram_used";
        visualization = "none";
      };

      widget.brightness = {
        show_glyph = true;
        show_label = true;
        show_when_unavailable = false;
      };

      widget.weather = {
        show_condition = false;
        show_temperature = true;
      };

      widget.tray = {
        hide_passive = false;
      };
    };
  };
}
