{ config, pkgs, ... }: {
  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  nixpkgs.config.allowUnfree = true;

  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 14d";
  };
  
  time.timeZone = "Europe/Vienna";

  i18n.defaultLocale = "en_US.UTF-8";
  i18n.extraLocaleSettings = {
    LC_ADDRESS = "de_AT.UTF-8";
    LC_IDENTIFICATION = "de_AT.UTF-8";
    LC_MEASUREMENT = "de_AT.UTF-8";
    LC_MONETARY = "de_AT.UTF-8";
    LC_NAME = "de_AT.UTF-8";
    LC_NUMERIC = "de_AT.UTF-8";
    LC_TIME = "de_AT.UTF-8";
  };

  console = {
    font = "Lat2-Terminus16";
    keyMap = "de";
  };
  
  services.flatpak.enable = true;

  # Enable Nix dynamic linker (needed by Jetbrains)
  programs.nix-ld.enable = true;

  services.printing = {
    enable = true;
    
    drivers = with pkgs; [
      brlaser
      gutenprint
    ];
  };

  # Enable Avahi for network discovery
  services.avahi = {
    enable = true;
    nssmdns4 = true;
    openFirewall = true;
  };

  xdg.portal = {
    enable = true;
    extraPortals = [ pkgs.xdg-desktop-portal-gtk ];
  };
}
