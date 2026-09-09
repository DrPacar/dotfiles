{
  pkgs,
  lib,
  ...
}: let
  selectedWallpaper = ./wallpapers/default.png;
in {
  services.hyprpaper = {
    enable = true;
    settings = {
      ipc = "on";
      splash = false;
      preload = ["${selectedWallpaper}"];
      wallpaper = [",${selectedWallpaper}"];
    };
  };

  # Ensure hyprpaper runs only in Hyprland sessions, avoiding interference with GNOME
  systemd.user.services.hyprpaper.Install.WantedBy = lib.mkForce ["hyprland-session.target"];
}
