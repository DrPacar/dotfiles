{
  pkgs,
  lib,
  ...
}: let
  selectedWallpaper = ./wallpapers/last_tree.jpg;
in {
  services.hyprpaper = {
    enable = true;
  };

  xdg.configFile."hypr/hyprpaper.conf".text = lib.mkForce ''
    ipc = on
    splash = false

    wallpaper {
      monitor = DP-3
      path = ${selectedWallpaper}
    }

    wallpaper {
      monitor = DP-4
      path = ${selectedWallpaper}
    }

    wallpaper {
      monitor =
      path = ${selectedWallpaper}
    }
  '';

  # Ensure hyprpaper runs only in Hyprland sessions, avoiding interference with GNOME
  systemd.user.services.hyprpaper.Install.WantedBy = lib.mkForce ["hyprland-session.target"];
}
