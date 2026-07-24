{ pkgs, ... }: {
  imports = [
    ../../modules/home/git.nix
    ../../modules/home/nh.nix
    ../../modules/home/ssh.nix
    ../../modules/home/fish.nix
    ../../modules/home/starship.nix
    ../../modules/home/neovim.nix
    ../../modules/home/firefox.nix
    ../../modules/home/ghostty.nix
    ../../modules/home/spotify.nix
  ];

  # Core user variables required by Home Manager
  home.username = "luka";
  home.homeDirectory = "/home/luka";

  # Do not change this once set; it determines compatibility for stateful data
  home.stateVersion = "24.05"; 
}
