{ config, pkgs, ... }: {
  imports = [
    ./hardware-configuration.nix
    ./boot.nix
    ./packages.nix
    ../base-system.nix
  ];
  services.flatpak.enable = true;

  xdg.portal = {
    enable = true;
    extraPortals = [ pkgs.xdg-desktop-portal-gtk ];
  }; 
  
  networking.hostName = "lighthouse";
  networking.networkmanager.enable = true;
  systemd.services.NetworkManager-wait-online.enable = false;
  system.stateVersion = "24.05";

  programs.fish.enable = true;
  # Users
  users.users.luka = {
    isNormalUser = true;
    extraGroups = [ "wheel" "networkmanager" ];
    shell = pkgs.fish;
  };
  home-manager.users.luka = import ../../home/luka-lighthouse.nix;
}
