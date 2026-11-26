{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (lib) mkIf;
  cfg = config.server;
  notifyCfg = cfg.notify;
  ntfy = import ./_lib.nix {inherit config lib pkgs;};

  ntfyCtlPkg = pkgs.writeShellApplication {
    name = "ntfy-ctl";
    runtimeInputs = with pkgs; [
      systemd
      curl
      jq
      coreutils
    ];
    runtimeEnv = ntfy.commonEnv;
    text = builtins.readFile ./scripts/ntfy-ctl.sh;
  };

  ntfySendPkg = pkgs.writeShellApplication {
    name = "ntfy-send";
    runtimeInputs = [ntfyCtlPkg];
    text = ''
      exec ntfy-ctl send "$@"
    '';
  };
in {
  config = mkIf (cfg.enable && notifyCfg.enable && notifyCfg.cli.enable) {
    environment.systemPackages = [
      ntfyCtlPkg
      ntfySendPkg
    ];
  };
}
