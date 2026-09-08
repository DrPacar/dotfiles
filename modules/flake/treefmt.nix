{inputs, ...}: {
  imports = [inputs.treefmt-nix.flakeModule];

  perSystem = {...}: {
    treefmt.config = {
      projectRootFile = "flake.nix";
      programs = {
        alejandra.enable = true;
        shfmt.enable = true;
      };
    };
  };
}
