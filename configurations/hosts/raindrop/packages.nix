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

  # Declarative CIFS automount of /data from lighthouse
  client.shares.data.enable = true;
}
