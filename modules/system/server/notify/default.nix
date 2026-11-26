{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (lib) mkIf optionalAttrs;
  cfg = config.server;
  notifyCfg = cfg.notify;
  ntfy = import ./_lib.nix {inherit config lib pkgs;};
in {
  config = mkIf (cfg.enable && notifyCfg.enable) {
    assertions = [
      {
        assertion = notifyCfg.topic != "";
        message = "server.notify: 'topic' cannot be empty.";
      }
      {
        assertion = notifyCfg.alertTopic != "";
        message = "server.notify: 'alertTopic' cannot be empty.";
      }
    ];

    services.ntfy-sh = {
      enable = true;
      settings =
        {
          base-url = ntfy.baseUrl;
          listen-http = "127.0.0.1:${toString notifyCfg.port}";
          behind-proxy = true;
          web-root = "app";
          cache-duration = notifyCfg.cacheDuration;
          cache-startup-queries = "pragma journal_mode = WAL;";
          keepalive-interval = notifyCfg.keepaliveInterval;
        }
        // optionalAttrs (notifyCfg.upstreamBaseUrl != null) {
          upstream-base-url = notifyCfg.upstreamBaseUrl;
        }
        // optionalAttrs (notifyCfg.exemptHosts != []) {
          visitor-request-limit-exempt-hosts = lib.concatStringsSep "," notifyCfg.exemptHosts;
        };
    };

    systemd.services.ntfy-sh.serviceConfig = {
      Restart = "on-failure";
      RestartSec = "5s";
    };
  };
}
