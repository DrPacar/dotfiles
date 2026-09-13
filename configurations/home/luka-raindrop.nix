{
  lib,
  mod,
  ...
}: {
  imports = lib.concatMap mod [
    # shell
    "base"
    "terminals/ghostty"
    "dev"
    "ai"

    # applications
    "browsers/firefox-family/zen-browser"
    "media"
    #"jetbrains"
    #"onlyoffice"
    "thunderbird"

    # gui
    "hyprland"
  ];

  home.username = "luka";
  home.homeDirectory = "/home/luka";

  home.stateVersion = "24.05";
}
