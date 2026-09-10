{
  pkgs,
  lib,
  ...
}: let
  selectedWallpaper = ./wallpapers/last_tree.jpg;
in {
  services.hyprpaper = {
    enable = true;
    settings = {
      ipc = "on";
      splash = false;
      preload = ["${selectedWallpaper}"];
      wallpaper = [
        "DP-3,${selectedWallpaper}"
        "DP-4,${selectedWallpaper}"
        ",${selectedWallpaper}"
      ];
    };
  };

  # Ensure hyprpaper runs only in Hyprland sessions, avoiding interference with GNOME
  systemd.user.services.hyprpaper.Install.WantedBy = lib.mkForce ["hyprland-session.target"];
}
