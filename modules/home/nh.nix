{ pkgs, ... }: {
  home.packages = with pkgs; [
    nh
  ];

  home.sessionVariables = {
    FLAKE = "$HOME/dotfiles"; 
  };
}
