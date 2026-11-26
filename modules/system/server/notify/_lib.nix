# Shared URLs, domain builders, and runtime environment for server.notify.
# Prefixed with '_' so lib/mod.nix does not auto-import this helper directly as a NixOS module.
{config, ...}: let
  cfg = config.server;
  notifyCfg = cfg.notify;

  notifyDomain =
    if cfg.domain != null
    then "${notifyCfg.subdomain}.${cfg.domain}"
    else "${notifyCfg.subdomain}.${config.networking.hostName}";

  baseUrl =
    if cfg.domain != null
    then "https://${notifyDomain}"
    else "http://127.0.0.1:${toString notifyCfg.port}";

  localUrl = "http://127.0.0.1:${toString notifyCfg.port}";
  mediaUrl = "${localUrl}/${notifyCfg.topic}";
  alertsUrl = "${localUrl}/${notifyCfg.alertTopic}";

  commonEnv = {
    NTFY_PORT = toString notifyCfg.port;
    NTFY_LOCAL_URL = localUrl;
    NTFY_BASE_URL = baseUrl;
    NTFY_MEDIA_TOPIC = notifyCfg.topic;
    NTFY_ALERT_TOPIC = notifyCfg.alertTopic;
  };
in {
  inherit
    notifyDomain
    baseUrl
    localUrl
    mediaUrl
    alertsUrl
    commonEnv
    ;
}
