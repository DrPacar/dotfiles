{
  pkgs,
  lib,
  mod,
  ...
}: {
  imports =
    lib.concatMap mod [
      # gui
      "gnome"
    ]
    ++ [
      ../base-packages.nix
    ];
}
