{ pkgs, ... }: {
  home.packages = [
    pkgs.microfetch
  ];

  programs.fish = {
    enable = true;
    interactiveShellInit = ''
      set -g fish_greeting ""
      microfetch
    '';

    shellAbbrs = {
      d = "cd ~/dotfiles";
    };
  }; 
}
