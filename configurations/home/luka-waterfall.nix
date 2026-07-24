{ pkgs, lib, mod, ... }: {
  imports = lib.concatMap mod [
    "base"
    "firefox"
    "ghostty"
    "spotify"
  ];

  home.username = "luka";
  home.homeDirectory = "/home/luka";

  home.stateVersion = "24.05"; 
}
