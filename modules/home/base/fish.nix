{pkgs, ...}: {
  home.packages = with pkgs; [
    microfetch
  ];

  programs.fish = {
    enable = true;

    # Plugins for fuzzy finding, clean history, and colored man pages
    plugins = [
      {
        name = "fzf-fish";
        src = pkgs.fishPlugins.fzf-fish.src;
      }
      {
        name = "sponge";
        src = pkgs.fishPlugins.sponge.src;
      }
      {
        name = "colored-man-pages";
        src = pkgs.fishPlugins.colored-man-pages.src;
      }
    ];

    # Modern abbreviations (expand with Space/Enter)
    shellAbbrs = {
      # Navigation
      d = "cd ~/dotfiles";
      u = "cd ~/uni";
      s = "cd ~/shared";
      wo = "work_on";

      # File listing with eza
      ls = "eza --icons";
      ll = "eza -l --icons --git --group-directories-first";
      lla = "eza -la --icons --git --group-directories-first";
      lt = "eza --tree --level=2 --icons";

      # Git productivity
      gs = "git status";
      ga = "git add";
      gc = "git commit";
      gp = "git push";
      gd = "git diff";
      gl = "git log --oneline --graph --decorate";

      # NixOS & system management
      nos = "nh os switch";
      nob = "nh os boot";
      nfu = "nix flake update";
      nc = "nh clean all --keep 5";
    };

    # Custom helper functions
    functions = {
      mkcd = ''
        mkdir -p $argv[1]; and cd $argv[1]
      '';
    };

    interactiveShellInit = ''
      set -g fish_greeting ""
      microfetch

      # Completions for send_file script
      complete -c send_file -s n -l no-auto -d "Disable auto-selecting device"
      complete -c send_file -s h -l help -d "Show help message"
      complete -c send_file -F
    '';
  };
}
