{ ... }:
{
  flake.homeModules.git =
    { ... }:
    {
      programs.git = {
        enable = true;
        settings = {
         user.name = "DrPacar";
         user.email = "lukapacar11@gmail.com";
        }
      };
    };
}