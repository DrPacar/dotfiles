{ pkgs, lib, mod, ... }: {
  imports = lib.concatMap mod [
    "base"
    "browsers/firefox-family"
    "browsers/firefox-family"
    "terminals/ghostty"
    "media"
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
