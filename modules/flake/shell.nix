{inputs, ...}: {
  perSystem = {
    pkgs,
    config,
    ...
  }: {
    devShells.default = pkgs.mkShell {
      shellHook = config.pre-commit.installationScript;
    };
  };
}
