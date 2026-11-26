{
  config,
  lib,
  ...
}: let
  inherit (lib) mkOption types;
  cfg = config.server.notify;
in {
  options.server.notify = {
    enable = mkOption {
      type = types.bool;
      default = false;
      description = "Enable self-hosted ntfy push notification server, web app, and CLI helpers.";
    };

    port = mkOption {
      type = types.port;
      default = 2586;
      description = "Internal HTTP port on which ntfy-sh listens.";
    };

    subdomain = mkOption {
      type = types.str;
      default = "notify";
      description = "Subdomain for ntfy web app and API (e.g. notify.lukpac.dev).";
    };

    topic = mkOption {
      type = types.str;
      default = "media";
      description = "Default topic for media download and request notifications (Sonarr, Radarr, qBittorrent, Jellyseerr).";
    };

    alertTopic = mkOption {
      type = types.str;
      default = "alerts";
      description = "Dedicated topic for infrastructure, watchdog, backup, and service health alerts.";
    };

    cacheDuration = mkOption {
      type = types.str;
      default = "72h";
      description = "Duration to retain notification history in SQLite cache and the web interface.";
    };

    keepaliveInterval = mkOption {
      type = types.str;
      default = "45s";
      description = "Keepalive interval for SSE/WebSocket client streams behind reverse proxies.";
    };

    upstreamBaseUrl = mkOption {
      type = types.nullOr types.str;
      default = "https://ntfy.sh";
      description = "Upstream ntfy server for iOS/mobile instant push wakeups (null disables upstream forwarding).";
    };

    exemptHosts = mkOption {
      type = types.listOf types.str;
      default = [
        "127.0.0.1"
        "::1"
        "192.168.0.0/24"
        "100.64.0.0/10"
      ];
      description = "IPs or CIDRs exempt from ntfy visitor request rate-limiting so burst local/Tailnet alerts are never throttled.";
    };

    cli.enable = mkOption {
      type = types.bool;
      default = true;
      description = "Install 'ntfy-ctl' and 'ntfy-send' CLI utilities in environment.systemPackages.";
    };
  };
}
