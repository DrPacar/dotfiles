{ ... }:
{
  flake.homeModules.shell =
    { pkgs, lib, ... }:
    {
      programs.fish = {
        enable = true;
	
	shellAbbrs = {
	  d = "cd ~/dotfiles";
	
	  ll = "ls -l";
	  lla = "ls -la";

	  gs = "git status";
	};

        interactiveShellInit = ''
          set fish_greeting
	  fastfetch
        '';
      };
    };
}
