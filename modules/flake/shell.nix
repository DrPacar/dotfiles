{inputs, ...}: {
  perSystem = {
    pkgs,
    config,
    ...
  }: {
    devShells.default = pkgs.mkShell {
      name = "dotfiles";

      packages = builtins.attrValues {
        inherit
          (pkgs)
          git
          just
          ;
      };

      shellHook = config.pre-commit.installationScript;
    };
  };
}
