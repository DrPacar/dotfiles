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
    "hyprland"
    "kdeconnect"
    "virtualization"

    # gui
    "gnome"
    "greeter"
  ];
}
