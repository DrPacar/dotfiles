{ config, pkgs, ... }: {
  imports = [
    ./hardware-configuration.nix
    ./boot.nix
    ./packages.nix
    ../base-system.nix
  ];
  
  networking.hostName = "waterfall";
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
  home-manager.users.luka = import ../../home/luka-waterfall.nix;

  # Grafik & GNOME (Bewährtes Setup)[cite: 1]
  services.xserver.enable = true;
  services.xserver.displayManager.gdm.enable = true;
  services.xserver.desktopManager.gnome.enable = true;

  services.xserver.xkb = {
    layout = "at";
    variant = "";
  };

  hardware.graphics.enable = true;
  # Audio
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    pulse.enable = true;
  };
}
