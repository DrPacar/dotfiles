{
  pkgs,
  lib,
  mod,
  ...
}: {
  imports = lib.concatMap mod [
    "base"
    "gaming"
    "gnome"
    "hyprland"
    "kdeconnect"
    "virtualization"
    "greeter"
  ];
}
