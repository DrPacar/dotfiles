{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (lib) mkIf;
  cfg = config.server;
  adg = import ./_lib.nix {inherit config lib pkgs;};

  adguardCli = pkgs.writeShellApplication {
    name = "adguard";
    runtimeInputs = with pkgs; [
      systemd
      iproute2
      curl
      jq
      python3
      gawk
      gnugrep
      coreutils
    ];
    runtimeEnv = adg.commonEnv;
    text = builtins.readFile ./scripts/adguard-status.sh;
  };
in {
  config = mkIf (cfg.enable && cfg.adguard.enable && cfg.adguard.cli.enable) {
    environment.systemPackages = [
      adguardCli
    ];
  };
}
