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

      environment.systemPackages = with pkgs; [
        nix-output-monitor
        nvd
      ];
    };
}