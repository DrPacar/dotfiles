{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (lib) mkIf;
  cfg = config.server;
  vw = import ./_lib.nix {inherit config lib pkgs;};

  vaultwardenCli = pkgs.writeShellApplication {
    name = "vaultwarden-ctl";
    runtimeInputs = with pkgs; [
      systemd
      curl
      sqlite
      coreutils
      gawk
    ];
    runtimeEnv = vw.commonEnv;
    text = builtins.readFile ./scripts/vaultwarden-ctl.sh;
  };
in {
  config = mkIf (cfg.enable && cfg.vaultwarden.enable && cfg.vaultwarden.cli.enable) {
    # Exposed as `vaultwarden-ctl` so it stays clearly distinct from the server binary
    environment.systemPackages = [
      vaultwardenCli
    ];
  };
}
