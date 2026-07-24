{ pkgs, lib, mod, ... }: {
  imports = lib.concatMap mod [
    "base"
    "browsers/firefox"
    "browsers/zen-browser"
    "terminals/ghostty"
    "media"
  ];

  home.username = "luka";
  home.homeDirectory = "/home/luka";

  home.stateVersion = "24.05"; 
}
