{ config, pkgs, ... }: {
  services.flatpak.remotes = [{
    name = "flathub";
    location = "https://dl.flathub.org/repo/flathub.flatpakrepo";
  }];

  services.flatpak.packages = [
    "org.vinegarhq.Sober"
  ];

  xdg.dataFile."flatpak/overrides/org.vinegarhq.Sober".text = ''
    [Context]
    filesystems=/run/current-system/sw/share/icons:ro;

    [Environment]
    GDK_BACKEND=x11
  '';

  home.shellAliases = {
    sober = "flatpak run org.vinegarhq.Sober";
  };
}
