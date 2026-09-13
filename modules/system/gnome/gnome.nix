{
  lib,
  pkgs,
  ...
}: {
  services.xserver.enable = true;
  services.xserver.xkb = {
    layout = "at";
    variant = "";
  };
  services.displayManager.gdm.enable = lib.mkDefault true;
  services.desktopManager.gnome.enable = true;

  programs.dconf.enable = true;

  environment.gnome.excludePackages = with pkgs; [
    gnome-tour
    gnome-connections
    epiphany
    geary
  ];
}
