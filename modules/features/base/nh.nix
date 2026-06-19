{ ... }:
{
  flake.homeModules.nh =
    { pkgs, ... }:
    {
      programs.nh = {
        enable = true;
        clean.enable = true;
        clean.extraArgs = "--keep-since 1w --keep 5";
        flake = "/home/luka/dotfiles/";
      };

      # Richtig für Home-Manager: home.packages nutzen!
      home.packages = with pkgs; [
        nix-output-monitor
        nvd
      ];
    };
}