{
  services.xserver.enable = true;
  services.xserver.xkb = {
    layout = "at";
    variant = "";
  };
  services.displayManager.gdm.enable = true;
  services.desktopManager.gnome.enable = true;
  hardware.graphics.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    pulse.enable = true;
  };
  programs.dconf.enable = true;
}
