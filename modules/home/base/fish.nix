{pkgs, ...}: {
  home.packages = [
    pkgs.microfetch
  ];

  programs.fish = {
    enable = true;
    shellAbbrs = {
      d = "cd ~/dotfiles";
      u = "cd ~/uni";
      ll = "ls -l";
      lla = "ls -la";
      gs = "git status";
      wo = "work_on";
    };
    interactiveShellInit = ''
      direnv hook fish | source
      set -g fish_greeting ""
      microfetch
    '';
  };
}
