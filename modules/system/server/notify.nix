{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (lib) mkIf mkOption types;
  cfg = config.server;
  notifyCfg = cfg.notify;

  notifyDomain =
    if cfg.domain != null
    then "${notifyCfg.subdomain}.${cfg.domain}"
    else "${notifyCfg.subdomain}.lighthouse";
in {
  options.server.notify = {
    enable = mkOption {
      type = types.bool;
      default = false;
      description = "Enable self-hosted ntfy push notification server and web client.";
    };

    port = mkOption {
      type = types.port;
      default = 2586;
      description = "Internal HTTP port on which ntfy-sh listens.";
    };

    subdomain = mkOption {
      type = types.str;
      default = "notify";
      description = "Subdomain for ntfy web app and API (e.g. notify.media.lukpac.dev).";
    };

    topic = mkOption {
      type = types.str;
      default = "media";
      description = "Default notification topic for Arr stack media downloads and status.";
    };

    cacheDuration = mkOption {
      type = types.str;
      default = "24h";
      description = "Duration to retain notification history in the web interface and cache.";
    };
  };

  config = mkIf (cfg.enable && notifyCfg.enable) {
    # -------------------------------------------------------------------------
    # ntfy-sh Service Configuration
    # -------------------------------------------------------------------------
    services.ntfy-sh = {
      enable = true;
      settings = {
        base-url = "https://${notifyDomain}";
        upstream-base-url = "https://ntfy.sh";
        listen-http = "127.0.0.1:${toString notifyCfg.port}";
        behind-proxy = true;
        web-root = "app";
        cache-duration = notifyCfg.cacheDuration;
      };
    };

    # -------------------------------------------------------------------------
    # CLI Helper Tool: ntfy-send
    # -------------------------------------------------------------------------
    environment.systemPackages = [
      (pkgs.writeShellScriptBin "ntfy-send" ''
        set -eu
        TOPIC="''${1:-${notifyCfg.topic}}"
        MESSAGE="''${2:-Notification from $(hostname)}"
        TITLE="''${3:-Server Alert}"
        TAGS="''${4:-bell}"

        ${pkgs.curl}/bin/curl -s \
          -H "Title: $TITLE" \
          -H "Tags: $TAGS" \
          -d "$MESSAGE" \
          "http://127.0.0.1:${toString notifyCfg.port}/$TOPIC"
      '')
    ];
  };
}
