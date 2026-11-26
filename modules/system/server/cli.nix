{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (lib) mkIf;
  cfg = config.server;
  arrCfg = cfg.arr or {};

  serverCheckCli = pkgs.writeShellApplication {
    name = "server-check";
    runtimeInputs = with pkgs; [
      systemd
      coreutils
      gawk
      gnugrep
    ];
    runtimeEnv = {
      HAS_SYSTEM_VPN =
        if (config.networking.systemVPN.enable or false)
        then "1"
        else "0";
      HAS_ARR_VPN =
        if ((arrCfg.enable or false) && (arrCfg.vpn.enable or false))
        then "1"
        else "0";
      HAS_ARR_QBIT =
        if ((arrCfg.enable or false) && (arrCfg.qbittorrent.enable or false))
        then "1"
        else "0";
      HAS_ADGUARD =
        if (cfg.adguard.enable or false)
        then "1"
        else "0";
      HAS_VAULTWARDEN =
        if ((cfg.vaultwarden.enable or false) && (cfg.vaultwarden.cli.enable or true))
        then "1"
        else "0";
      HAS_NOTIFY =
        if ((cfg.notify.enable or false) && (cfg.notify.cli.enable or true))
        then "1"
        else "0";
      HAS_BESZEL =
        if ((cfg.beszel.enable or false) && (cfg.beszel.cli.enable or true))
        then "1"
        else "0";
      HAS_SHARES =
        if ((config.networking.shares.enable or false) && (config.networking.shares.cli.enable or false))
        then "1"
        else "0";
      CHECK_STORAGE_PATHS =
        if (arrCfg.enable or false)
        then "/ ${arrCfg.dataDir}"
        else "/";
    };
    text = builtins.readFile ./scripts/server-check.sh;
  };
in {
  config = mkIf (cfg.enable && cfg.cli.enable) {
    environment.systemPackages = [
      serverCheckCli
    ];
  };
}
