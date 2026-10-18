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
    "sops"
    "openconnect"

    # gui
    "hyprland"
    "greeter"
  ];
}
