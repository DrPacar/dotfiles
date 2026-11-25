{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (lib) mkIf;
  cfg = config.networking.shares;
  shares = import ./_lib.nix {inherit config lib;};

  manifestFile = pkgs.writeText "shares-manifest.json" shares.manifestJson;

  sharesCli = pkgs.writeShellApplication {
    name = "shares";
    runtimeInputs = with pkgs; [
      systemd
      python3
      util-linux
      coreutils
    ];
    runtimeEnv = {
      SHARES_MANIFEST_FILE = "${manifestFile}";
    };
    text = builtins.readFile ./scripts/shares-ctl.sh;
  };
in {
  config = mkIf (cfg.enable && cfg.cli.enable) {
    environment.systemPackages = [
      sharesCli
    ];
  };
}
