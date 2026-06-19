{ self, pkgs, ... }:
{
  flake.homeModules.raindropHome =
    { ... }:
    {
      home.username = "luka";
      home.homeDirectory = "/home/luka";
      home.stateVersion = "25.05";

      imports = [
        self.homeModules.git
        self.homeModules.nh
        self.homeModules.ssh
        self.homeModules.cli-tools
        self.homeModules.shell
        self.homeModules.starship

        self.homeModules.terminal
        self.homeModules.firefox
      ];

      home.packages = with pkgs; [
        python3
        just
        spotify
      ];

      programs.home-manager.enable = true;
    };
}