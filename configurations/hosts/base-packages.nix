{
  pkgs,
  lib,
  mod,
  ...
}: {
  imports = lib.concatMap mod [
    # shell
    "base"

    # network
    "network"

    # applications
    "kdeconnect"
    "ios"
    "sops"
    "openconnect"
    "backup"

    # gui
    "hyprland"
    "greeter"
  ];
}
