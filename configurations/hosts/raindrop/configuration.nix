{ config, pkgs, ... }: {
  imports = [
    ./hardware-configuration.nix
    ./boot.nix
    ../base-system.nix
    ../../../modules/hosts/steam.nix
  ];

  networking.hostName = "raindrop";
  system.stateVersion = "24.05";

  programs.fish.enable = true;
  # Users
  users.users.luka = {
    isNormalUser = true;
    extraGroups = [ "wheel" "networkmanager" ];
    shell = pkgs.fish;
  };
  home-manager.users.luka = import ../../home/luka-raindrop.nix;

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
