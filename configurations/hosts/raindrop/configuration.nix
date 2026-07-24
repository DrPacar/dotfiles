{ config, pkgs, ... }: {
  imports = [
    ./hardware-configuration.nix
    ./boot.nix
    ./packages.nix
    ../base-system.nix
  ];

  networking.hostName = "raindrop";
  networking.networkmanager = {
    enable = true;
  }
  system.stateVersion = "24.05";

  programs.fish.enable = true;
  # Users
  users.users.luka = {
    isNormalUser = true;
    extraGroups = [ "wheel" "networkmanager" ];
    shell = pkgs.fish;
  };
  home-manager.users.luka = import ../../home/luka-raindrop.nix;
}
