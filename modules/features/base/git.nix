{ ... }:
{
  flake.homeModules.ssh =
    { ... }:
    {
      programs.git = {
        enable = true;
        user.name = "DrPacar";
        user.email = "lukapacar11@gmail.com";
      };
    };
}