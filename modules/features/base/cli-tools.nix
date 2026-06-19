{ ... }:
{
  flake.homeModules.cli-tools =
    { pkgs, ... }:
    {
      programs = {
        btop = {
          enable = true;
          settings = {
            color_theme = "stylix";
            vim_keys = true;
          };
        };

        fzf = {
          enable = true;
          enableFishIntegration = true;
        };

        eza = {
          enable = true;
          git = true;
          icons = "auto";
          extraOptions = [
            "--group-directories-first"
            "--header"
          ];
        };

        bat = {
          enable = true;
          config = {
            style = "plain";
          };
        };
      };

      home.packages = with pkgs; [
        ripgrep
        fd
        fastfetch
      ];
    };
}