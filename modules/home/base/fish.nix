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
      s = "cd ~/shared";
    };
    interactiveShellInit = ''
      direnv hook fish | source
      set -g fish_greeting ""
      microfetch

      # Completions for send_file script
      complete -c send_file -s n -l no-auto -d "Disable auto-selecting device"
      complete -c send_file -s h -l help -d "Show help message"
      complete -c send_file -F
    '';
  };
}
