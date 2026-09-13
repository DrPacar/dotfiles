{
  config,
  pkgs,
  ...
}: {
  imports = [
    ./hardware-configuration.nix
    ./disk.nix
    ./users.nix
    ./boot.nix
    ./packages.nix
    ../base-system.nix
  ];

  networking.hostName = "lighthouse";

  networking.networkmanager.enable = true;
  systemd.services.NetworkManager-wait-online.enable = false;

  system.stateVersion = "24.05";
}
