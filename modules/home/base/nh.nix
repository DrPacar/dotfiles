{ pkgs, ... }: {
  programs.nh = {
    enable = true;

    flake = "$HOME/dotfiles";

    clean = {
      enable = true;
      dates = "weekly";
      
      extraArgs = "--keep-since 7d --keep 3";
    };
  };

  home.packages = with pkgs; [
    nix-output-monitor
    nvd
  ];
}
