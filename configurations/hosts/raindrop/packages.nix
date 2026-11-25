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

  # Do not use haven / Tailnet DNS on this mobile client
  client.tailscale.acceptDns = false;
}
