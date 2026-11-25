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
      "server"

      # gui
      "gnome"
    ]
    ++ [
      ../base-packages.nix
    ];

  # Declarative CIFS automount of /data from haven (direct LAN IP works even when Tailscale is off)
  networking.shares = {
    enable = true;
    entries.data = {
      host = "192.168.0.2";
      symlink = {
        enable = true;
        path = "/home/luka/haven/data";
      };
    };
  };

  # Use haven / Tailnet DNS on lighthouse
  client.tailscale.acceptDns = true;
}
