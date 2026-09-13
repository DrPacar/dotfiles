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
    "kdeconnect"

    # gui
    "hyprland"
    "greeter"
  ];
}
