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
      "arr"

      # gui
      "gnome"
    ]
    ++ [
      ../base-packages.nix
    ];
  # Media automation stack (Arr Stack)
  arr = {
    enable = true;
    jellyfin.hardwareAcceleration = "qsv"; # optional: Intel QuickSync aktivieren
    vpn.enable = true;
  };
}
