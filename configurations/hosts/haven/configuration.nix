{
  config,
  pkgs,
  lib,
  mod,
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

  networking.hostName = "haven";
  networking.nameservers = [
    "1.1.1.1"
    "1.0.0.1"
  ];

  networking.networkmanager = {
    enable = true;
    wifi.powersave = false;
  };
  systemd.services.NetworkManager-wait-online.enable = false;

  # Headless server: disable desktop / audio services from base-system.nix
  services.pipewire.enable = lib.mkForce false;
  security.rtkit.enable = lib.mkForce false;
  services.printing.enable = lib.mkForce false;
  services.flatpak.enable = lib.mkForce false;
  xdg.portal.enable = lib.mkForce false;

  system.stateVersion = "24.05";
}
