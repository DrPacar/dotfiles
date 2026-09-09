{lib, ...}: {
  services.swaync = {
    enable = true;

    settings = {
      positionX = "right";
      positionY = "top";
      layer = "overlay";
      control-center-layer = "top";
      layer-shell = true;
      cssPriority = "application";
      control-center-margin-top = 10;
      control-center-margin-bottom = 10;
      control-center-margin-right = 10;
      control-center-margin-left = 10;
      control-center-width = 330;
      notification-window-width = 330;
      notification-2fa-action = true;
      notification-inline-replies = true;
      notification-icon-size = 42;
      notification-body-image-height = 90;
      notification-body-image-width = 180;
      timeout = 6;
      timeout-low = 3;
      timeout-critical = 0;
      fit-to-screen = true;

      widgets = [
        "title"
        "notifications"
      ];

      widget-config = {
        title = {
          text = "Mitteilungen";
          clear-all-button = true;
          button-text = "Leeren";
        };
      };
    };

    style = ''
      * {
        font-family: "JetBrainsMono Nerd Font", monospace;
        font-size: 12px;
        transition: 150ms ease;
      }

      .control-center {
        background: rgba(22, 22, 30, 0.90);
        border: 1px solid rgba(122, 162, 247, 0.25);
        border-radius: 14px;
        padding: 12px;
        color: #c0caf5;
        box-shadow: 0 10px 30px rgba(0, 0, 0, 0.6);
      }

      .control-center .widget-title {
        color: #7aa2f7;
        font-weight: bold;
        font-size: 14px;
        padding: 4px 6px 8px 6px;
      }

      .control-center .widget-title button {
        background: rgba(36, 40, 59, 0.8);
        color: #c0caf5;
        border: 1px solid rgba(122, 162, 247, 0.2);
        border-radius: 6px;
        padding: 4px 10px;
        font-size: 11px;
      }

      .control-center .widget-title button:hover {
        background: #7aa2f7;
        color: #1a1b26;
      }

      .notification-row {
        outline: none;
      }

      .notification {
        background: rgba(36, 40, 59, 0.85);
        border: 1px solid rgba(122, 162, 247, 0.15);
        border-radius: 10px;
        margin: 5px 0;
        padding: 10px;
        color: #c0caf5;
        box-shadow: 0 2px 8px rgba(0, 0, 0, 0.3);
      }

      .notification.critical {
        border: 1px solid #f7768e;
      }

      .notification-content {
        margin: 2px;
      }

      .summary {
        font-weight: bold;
        color: #7aa2f7;
        font-size: 13px;
      }

      .body {
        color: #c0caf5;
        font-size: 12px;
      }

      .close-button {
        background: rgba(26, 27, 38, 0.8);
        color: #c0caf5;
        border-radius: 100%;
        padding: 2px;
      }

      .close-button:hover {
        background: #f7768e;
        color: #1a1b26;
      }
    '';
  };

  # Ensure swaync runs only in Hyprland sessions, avoiding interference with GNOME
  systemd.user.services.swaync.Install.WantedBy = lib.mkForce ["hyprland-session.target"];
}
