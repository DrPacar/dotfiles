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

      # gui
      "gnome"
    ]
    ++ [
      ../base-packages.nix
    ];
}
