{
  config,
  pkgs,
  ...
}: {
  imports = [
    ./hardware-configuration.nix
    ./users.nix
    ./boot.nix
    ./packages.nix
    ../base-system.nix
  ];

  networking.hostName = "raindrop";

  networking.networkmanager.enable = true;

  system.stateVersion = "24.05";
}
