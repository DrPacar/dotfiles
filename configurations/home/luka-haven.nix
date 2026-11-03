{
  lib,
  mod,
  ...
}: {
  imports = lib.concatMap mod [
    # shell & CLI
    "base"
    "dev"
    "ai"
  ];

  home.username = "luka";
  home.homeDirectory = "/home/luka";

  home.stateVersion = "24.05";
}
