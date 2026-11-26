# Shared URLs, paths, runtime env, and sync payload for server.beszel.
# Prefixed with '_' so lib/mod.nix does not auto-import this helper directly as a NixOS module.
{config, ...}: let
  cfg = config.server;
  bzCfg = cfg.beszel;

  dataDir = "/var/lib/private/beszel-hub";
  dbPath = "${dataDir}/data.db";

  appUrl =
    if cfg.domain != null
    then "https://${bzCfg.subdomain}.${cfg.domain}"
    else "http://127.0.0.1:${toString bzCfg.port}";

  localUrl = "http://127.0.0.1:${toString bzCfg.port}";

  agentEnabled =
    bzCfg.agent.enable
    && (bzCfg.agent.key != null || bzCfg.agent.keyFile != null || bzCfg.agent.environmentFile != null);

  syncPayload = {
    dbPath = dbPath;
    appUrl = appUrl;
    trustedProxyHeaders = [
      "X-Real-IP"
      "X-Forwarded-For"
    ];
    ntfyEnable = bzCfg.notifications.ntfy.enable;
    ntfyUrl = bzCfg.notifications.ntfy.url;
    alertsEnable = bzCfg.alerts.enable;
    alertRules = bzCfg.alerts.rules;
    hostName = config.networking.hostName;
  };

  commonEnv = {
    BESZEL_HUB_PORT = toString bzCfg.port;
    BESZEL_LOCAL_URL = localUrl;
    BESZEL_APP_URL = appUrl;
    BESZEL_DB_PATH = dbPath;
    BESZEL_AGENT_ENABLED =
      if agentEnabled
      then "1"
      else "0";
    BESZEL_AGENT_PORT = toString bzCfg.agent.port;
    BESZEL_HOST_NAME = config.networking.hostName;
  };
in {
  inherit
    dataDir
    dbPath
    appUrl
    localUrl
    agentEnabled
    syncPayload
    commonEnv
    ;
}
