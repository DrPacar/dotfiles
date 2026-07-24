{ pkgs, ... }: {
  home.packages = [
    pkgs.microfetch
  ];

  programs.fish = {
    enable = true;
    shellAbbrs = {
      d = "cd ~/dotfiles";
      ll = "ls -l";
      lla = "ls -la";
      gs = "git status";
    };
    interactiveShellInit = ''
      set -g fish_greeting ""
      microfetch
    '';
  }; 
}
