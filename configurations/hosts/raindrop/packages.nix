{
  pkgs,
  lib,
  mod,
  ...
}: {
  imports =
    lib.concatMap mod [
      # network shares client
      "server/shares"

      # gui
      "gnome"
    ]
    ++ [
      ../base-packages.nix
    ];

  # Declarative CIFS automount of /data from haven (Tailscale IP works both remotely and locally)
  networking.shares = {
    enable = true;
    entries.data = {
      host = "100.64.0.1";
      symlink.enable = true;
    };
  };

  # Do not use haven / Tailnet DNS on this mobile client
  client.tailscale.acceptDns = false;
}
