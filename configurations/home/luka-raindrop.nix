{ pkgs, lib, mod, ... }: {
  imports = lib.concatMap mod [
    "base"
    "browsers/firefox-family/zen-browser"
    "terminals/ghostty"
    "media"
    #"jetbrains"
    #"onlyoffice"
    "dev"
    "gsconnect"
    "thunderbird"
  ];

  home.username = "luka";
  home.homeDirectory = "/home/luka";

  home.stateVersion = "24.05"; 

  dconf.settings = {
    "org/gnome/desktop/interface" = {
      color-scheme = "prefer-dark";
    };
  };
}
