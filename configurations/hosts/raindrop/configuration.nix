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
    ./monitors.nix
    ../base-system.nix
  ];

  networking.hostName = "raindrop";

  device.hasBattery = true;

  networking.networkmanager.enable = true;

  system.stateVersion = "24.05";
}
