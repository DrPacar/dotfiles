{
  pkgs,
  lib,
  mod,
  ...
}: {
  imports =
    lib.concatMap mod [
      # applications
      "gaming"
      "virtualization"
      "kdeconnect"

      # gui
      "gnome"
    ]
    ++ [
      ../base-packages.nix
    ];
}
