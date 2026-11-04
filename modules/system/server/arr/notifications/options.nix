{
  config,
  lib,
  ...
}: let
  inherit (lib) mkOption types;
  cfg = config.server.arr;
  notifyCfg = config.server.notify;
in {
  options.server.arr.notifications = {
    enable = mkOption {
      type = types.bool;
      default = config.server.notify.enable or false;
      description = "Enable automated notifications for Arr stack events (grab, download, upgrade) via ntfy.";
    };

    ntfyUrl = mkOption {
      type = types.str;
      default = "http://127.0.0.1:${toString (notifyCfg.port or 2586)}/${notifyCfg.topic or "media"}";
      description = "Internal ntfy endpoint URL for Arr stack events.";
    };

    jellyfinUrl = mkOption {
      type = types.str;
      default =
        if cfg.domain != null
        then "https://${cfg.jellyfin.subdomain}.${cfg.domain}"
        else if config.server.domain != null
        then "https://${cfg.jellyfin.subdomain}.${config.server.domain}"
        else "http://${config.networking.hostName}:8096";
      description = "Public Jellyfin URL embedded in download completion notifications.";
    };
  };
}
