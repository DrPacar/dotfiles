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
    "gnome"
    "kdeconnect"

    # gui
    "greeter"
  ];
}
