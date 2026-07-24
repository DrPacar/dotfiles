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

    shellAliases = {
      d = "cd ~/dotfiles";
    };
  }; 
}
