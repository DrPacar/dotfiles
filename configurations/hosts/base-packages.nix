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
    "ios"

    # gui
    "hyprland"
    "greeter"
  ];
}
