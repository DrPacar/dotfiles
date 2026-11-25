# Shared constants, paths, notification helper, and runtime environment for server.vaultwarden.
# Prefixed with '_' so lib/mod.nix does not auto-import this helper directly as a NixOS module.
{
  config,
  lib,
  pkgs,
}: let
  cfg = config.server;
  vwCfg = cfg.vaultwarden;
  inherit (import ../_lib.nix) mkNotifyBin;

  stateDirName =
    if lib.versionOlder config.system.stateVersion "24.11"
    then "bitwarden_rs"
    else "vaultwarden";

  dataDir = "/var/lib/${stateDirName}";

  vaultUrl =
    if cfg.domain != null
    then "https://${vwCfg.subdomain}.${cfg.domain}"
    else "http://127.0.0.1:${toString vwCfg.port}";

  localUrl = "http://127.0.0.1:${toString vwCfg.port}";

  notifyBin = mkNotifyBin {
    inherit pkgs lib config;
    inherit (vwCfg.notifications) enable handler;
    name = "vaultwarden-notify";
    title = "Vaultwarden";
  };

  commonEnv = {
    LOCAL_URL = localUrl;
    VAULT_URL = vaultUrl;
    DATA_DIR = dataDir;
    BACKUP_ENABLED =
      if vwCfg.backup.enable
      then "1"
      else "0";
    BACKUP_DIR = vwCfg.backup.dir;
    SIGNUPS_ALLOWED =
      if vwCfg.signupsAllowed
      then "true"
      else "false";
    INVITATIONS_ALLOWED =
      if vwCfg.invitationsAllowed
      then "true"
      else "false";
    NOTIFY_BIN = notifyBin;
  };
in {
  inherit
    dataDir
    vaultUrl
    localUrl
    notifyBin
    commonEnv
    ;
}
