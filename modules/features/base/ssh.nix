{ ... }:
{
  flake.homeModules.ssh =
    { ... }:
    {
      programs.ssh = {
        enable = true;
      };
    };
}