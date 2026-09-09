{...}: {
  programs.waybar = {
    enable = true;

    settings = {
      mainBar = {
        layer = "top";
        position = "top";
        height = 36;
        margin-top = 6;
        margin-left = 10;
        margin-right = 10;
        spacing = 4;

        modules-left = [
          "hyprland/workspaces"
          "hyprland/window"
        ];

        modules-center = [
          "clock"
          "mpris"
        ];

        modules-right = [
          "pulseaudio"
          "network"
          "cpu"
          "memory"
          "tray"
          "custom/notification"
          "custom/power"
        ];

        "hyprland/workspaces" = {
          disable-scroll = true;
          all-outputs = false;
          format = "{name}";
          on-click = "activate";
          persistent-workspaces = {
            "desc:Acer Technologies XZ272U V" = [1 2 3 4 5];
            "desc:Samsung Electric Company LS24AG32x" = [6 7 8 9 10];
          };
        };

        "hyprland/window" = {
          format = "{}";
          max-length = 40;
          separate-outputs = true;
          rewrite = {
            "(.*) — Mozilla Firefox" = "󰈹  $1";
            "(.*) — Zen Browser" = "󰈹  $1";
            "(.*) - Ghostty" = "  $1";
            "agy (.*)" = "󰘳  Antigravity";
          };
        };

        clock = {
          format = "󰥔  {:%H:%M}";
          format-alt = "󰃭  {:%A, %d. %B %Y  󰥔 %H:%M}";
          tooltip-format = "<tt><small>{calendar}</small></tt>";
          calendar = {
            mode = "year";
            mode-mon-col = 3;
            weeks-pos = "right";
            on-scroll = 1;
            format = {
              months = "<span color='#ff9e64'><b>{}</b></span>";
              days = "<span color='#c0caf5'><b>{}</b></span>";
              weeks = "<span color='#7dcfff'><b>W{}</b></span>";
              weekdays = "<span color='#7aa2f7'><b>{}</b></span>";
              today = "<span color='#f7768e'><b><u>{}</u></b></span>";
            };
          };
        };

        mpris = {
          format = "{player_icon}  {title} - {artist}";
          format-paused = "{status_icon}  <i>{title} - {artist}</i>";
          max-length = 30;
          player-icons = {
            default = "󰐊";
            spotify = "󰓇";
          };
          status-icons = {
            paused = "󰏤";
          };
        };

        pulseaudio = {
          format = "{icon}  {volume}%";
          format-bluetooth = "{icon}󰂯  {volume}%";
          format-muted = "󰝟  Muted";
          format-icons = {
            headphone = "󰋋";
            hands-free = "󰋎";
            headset = "󰋎";
            phone = "󰏲";
            portable = "󰏲";
            car = "󰄋";
            default = ["󰕿" "󰖀" "󰕾"];
          };
          on-click = "pavucontrol";
          on-click-right = "pamixer -t";
          scroll-step = 5;
        };

        network = {
          format-wifi = "󰤨  {signalStrength}%";
          format-ethernet = "󰈀  Wired";
          format-disconnected = "󰤭  Offline";
          tooltip-format = "{ifname} via {gwaddr}";
        };

        cpu = {
          format = "󰍛  {usage}%";
          interval = 2;
        };

        memory = {
          format = "󰘚  {percentage}%";
          interval = 2;
        };

        tray = {
          icon-size = 16;
          spacing = 8;
        };

        "custom/notification" = {
          tooltip = false;
          format = "{icon}";
          format-icons = {
            notification = "󱅫";
            none = "󰂚";
            dnd-notification = "󰂛";
            dnd-none = "󰂛";
            inhibited-notification = "󱅫";
            inhibited-none = "󰂚";
            dnd-inhibited-notification = "󰂛";
            dnd-inhibited-none = "󰂛";
          };
          return-type = "json";
          exec-if = "which swaync-client";
          exec = "swaync-client -swb";
          on-click = "swaync-client -t -sw";
          on-click-right = "swaync-client -d -sw";
          escape = true;
        };

        "custom/power" = {
          format = "⏻";
          tooltip = false;
          on-click = "rofi-power-menu";
        };
      };
    };

    style = ''
      * {
        font-family: "JetBrainsMono Nerd Font", monospace;
        font-size: 13px;
        font-weight: 600;
        min-height: 0;
        border: none;
        border-radius: 0;
      }

      window#waybar {
        background: rgba(22, 22, 30, 0.82);
        border: 1px solid rgba(122, 162, 247, 0.22);
        border-radius: 14px;
        color: #c0caf5;
      }

      #workspaces {
        background: rgba(36, 40, 59, 0.65);
        border-radius: 9px;
        margin: 4px 6px;
        padding: 1px 3px;
      }

      #workspaces button {
        padding: 0 10px;
        color: #565f89;
        border-radius: 7px;
        transition: all 0.2s ease;
      }

      #workspaces button.active {
        color: #1a1b26;
        background: #7aa2f7;
        font-weight: bold;
      }

      #workspaces button:hover {
        background: rgba(122, 162, 247, 0.2);
        color: #c0caf5;
      }

      #window {
        color: #7dcfff;
        padding: 0 12px;
        font-weight: 500;
      }

      #clock {
        background: rgba(36, 40, 59, 0.65);
        border-radius: 9px;
        padding: 0 14px;
        margin: 4px 3px;
        color: #c0caf5;
        font-weight: bold;
      }

      #mpris {
        background: rgba(36, 40, 59, 0.65);
        border-radius: 9px;
        padding: 0 12px;
        margin: 4px 3px;
        color: #bb9af7;
      }

      #pulseaudio, #network, #cpu, #memory, #tray, #custom-notification, #custom-power {
        background: rgba(36, 40, 59, 0.65);
        border-radius: 9px;
        padding: 0 11px;
        margin: 4px 3px;
      }

      #pulseaudio {
        color: #7aa2f7;
      }

      #pulseaudio.muted {
        color: #f7768e;
      }

      #network {
        color: #9ece6a;
      }

      #network.disconnected {
        color: #f7768e;
      }

      #cpu {
        color: #bb9af7;
      }

      #memory {
        color: #e0af68;
      }

      #tray {
        padding: 0 8px;
      }

      #tray > .passive {
        -gtk-icon-effect: dim;
      }

      #tray > .needs-attention {
        -gtk-icon-effect: highlight;
      }

      #custom-notification {
        color: #7aa2f7;
        font-size: 15px;
        padding: 0 10px;
      }

      #custom-power {
        color: #f7768e;
        font-size: 14px;
        padding: 0 12px;
        border-radius: 9px;
        transition: all 0.2s ease;
      }

      #custom-power:hover {
        background: #f7768e;
        color: #1a1b26;
      }

      tooltip {
        background: rgba(22, 22, 30, 0.95);
        border: 1px solid #7aa2f7;
        border-radius: 10px;
        color: #c0caf5;
        padding: 6px;
      }
    '';
  };
}
