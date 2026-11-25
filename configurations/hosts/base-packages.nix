{
  pkgs,
  lib,
  mod,
  ...
}: {
  imports = lib.concatMap mod [
    # shell
    "base"

    # network
    "network"

    # applications
    "kdeconnect"
    "ios"
    "sops"
    "openconnect"
    "backup"

    # gui
    "hyprland"
    "greeter"
  ];

  # Enable Tailscale client profile on desktop and laptop hosts
  client.tailscale.enable = true;
}
