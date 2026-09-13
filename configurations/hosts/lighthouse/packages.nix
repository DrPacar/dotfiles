{
  pkgs,
  lib,
  mod,
  ...
}: {
  imports = lib.concatMap mod [
    # shell
    "base"

    # applications
    "gaming"
    "kdeconnect"
    "virtualization"

    # gui
    "hyprland"
    "gnome"
    "greeter"
  ];
}
