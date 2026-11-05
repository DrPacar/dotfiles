{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (lib) mkIf mkOption types;
  cfg = config.server;
  arrCfg = config.server.arr or {};
  arrEnabled = arrCfg.enable or false;

  # Auto-discovered monitors from running server services
  autoDiscoveredMonitors = lib.optionals cfg.uptime-kuma.autoDiscover (
    # Arr Stack (Medien)
    lib.optional (arrEnabled && arrCfg.jellyfin.enable) {
      name = "Jellyfin";
      type = "http";
      url = "http://127.0.0.1:${toString arrCfg.jellyfin.port}/health";
      interval = 60;
      retry_interval = 60;
      maxretries = 2;
      group = "Medien & Streaming";
    }
    ++ lib.optional (arrEnabled && arrCfg.seerr.enable) {
      name = "Jellyseerr";
      type = "http";
      url = "http://127.0.0.1:${toString arrCfg.seerr.port}/api/v1/status";
      interval = 60;
      retry_interval = 60;
      maxretries = 2;
      group = "Medien & Streaming";
    }
    ++ lib.optional (arrEnabled && arrCfg.sonarr.enable) {
      name = "Sonarr";
      type = "http";
      url = "http://127.0.0.1:${toString arrCfg.sonarr.port}/ping";
      interval = 60;
      retry_interval = 60;
      maxretries = 2;
      group = "Medien & Streaming";
    }
    ++ lib.optional (arrEnabled && arrCfg.radarr.enable) {
      name = "Radarr";
      type = "http";
      url = "http://127.0.0.1:${toString arrCfg.radarr.port}/ping";
      interval = 60;
      retry_interval = 60;
      maxretries = 2;
      group = "Medien & Streaming";
    }
    ++ lib.optional (arrEnabled && arrCfg.prowlarr.enable) {
      name = "Prowlarr";
      type = "http";
      url = "http://127.0.0.1:${toString arrCfg.prowlarr.port}/ping";
      interval = 60;
      retry_interval = 60;
      maxretries = 2;
      group = "Medien & Streaming";
    }
    ++ lib.optional (arrEnabled && arrCfg.bazarr.enable) {
      name = "Bazarr";
      type = "http";
      url = "http://127.0.0.1:${toString arrCfg.bazarr.port}/ping";
      interval = 60;
      retry_interval = 60;
      maxretries = 2;
      group = "Medien & Streaming";
    }
    ++ lib.optional (arrEnabled && arrCfg.qbittorrent.enable) {
      name = "qBittorrent";
      type = "http";
      url = "http://127.0.0.1:${toString arrCfg.qbittorrent.webuiPort}/";
      interval = 60;
      retry_interval = 60;
      maxretries = 2;
      group = "Medien & Streaming";
    }
    ++ lib.optional (arrEnabled && arrCfg.flaresolverr.enable) {
      name = "FlareSolverr";
      type = "http";
      url = "http://127.0.0.1:${toString arrCfg.flaresolverr.port}/";
      interval = 60;
      retry_interval = 60;
      maxretries = 2;
      group = "Medien & Streaming";
    }
    # Central Server Services
    ++ lib.optional (cfg.vaultwarden.enable or false) {
      name = "Vaultwarden";
      type = "http";
      url = "http://127.0.0.1:${toString cfg.vaultwarden.port}/alive";
      interval = 60;
      retry_interval = 60;
      maxretries = 2;
      group = "Server & Cloud";
    }
    ++ lib.optional (cfg.immich.enable or false) {
      name = "Immich";
      type = "http";
      url = "http://127.0.0.1:${toString cfg.immich.port}/api/server/ping";
      interval = 60;
      retry_interval = 60;
      maxretries = 2;
      group = "Server & Cloud";
    }
    ++ lib.optional (cfg.paperless.enable or false) {
      name = "Paperless-ngx";
      type = "http";
      url = "http://127.0.0.1:${toString cfg.paperless.port}/";
      interval = 60;
      retry_interval = 60;
      maxretries = 2;
      group = "Server & Cloud";
    }
    ++ lib.optional (cfg.beszel.enable or false) {
      name = "Beszel";
      type = "http";
      url = "http://127.0.0.1:${toString cfg.beszel.port}/api/health";
      interval = 60;
      retry_interval = 60;
      maxretries = 2;
      group = "Server & Cloud";
    }
    ++ lib.optional (cfg.notify.enable or false) {
      name = "Ntfy";
      type = "http";
      url = "http://127.0.0.1:${toString cfg.notify.port}/v1/health";
      interval = 60;
      retry_interval = 60;
      maxretries = 2;
      group = "Server & Cloud";
    }
    ++ lib.optional (cfg.adguard.enable or false) {
      name = "AdGuard Home";
      type = "http";
      url = "http://127.0.0.1:${toString cfg.adguard.port}/";
      interval = 60;
      retry_interval = 60;
      maxretries = 2;
      group = "Netzwerk & Infrastruktur";
    }
    ++ lib.optional (cfg.adguard.enable or false) {
      name = "AdGuard DNS";
      type = "dns";
      hostname = "google.com";
      dns_resolve_server = "127.0.0.1";
      dns_resolve_type = "A";
      interval = 30;
      retry_interval = 30;
      maxretries = 2;
      group = "Netzwerk & Infrastruktur";
    }
  );

  networkMonitors = lib.optionals cfg.uptime-kuma.defaultNetworkMonitors [
    {
      name = "Gateway (Router)";
      type = "ping";
      hostname = cfg.uptime-kuma.gatewayIp;
      interval = 30;
      retry_interval = 30;
      maxretries = 2;
      group = "Netzwerk & Infrastruktur";
    }
    {
      name = "Internet (Cloudflare)";
      type = "ping";
      hostname = "1.1.1.1";
      interval = 30;
      retry_interval = 30;
      maxretries = 2;
      group = "Netzwerk & Infrastruktur";
    }
  ];

  allMonitors = autoDiscoveredMonitors ++ networkMonitors ++ cfg.uptime-kuma.extraMonitors;

  syncConfig = {
    cleanupUntracked = cfg.uptime-kuma.cleanupUntrackedMonitors;
    monitors = allMonitors;
    notification = {
      enable = cfg.uptime-kuma.notifications.ntfy.enable;
      name = cfg.uptime-kuma.notifications.ntfy.name;
      config = {
        type = "ntfy";
        ntfyserverurl = cfg.uptime-kuma.notifications.ntfy.serverUrl;
        ntfytopic = cfg.uptime-kuma.notifications.ntfy.topic;
        ntfyPriority = cfg.uptime-kuma.notifications.ntfy.priority;
        ntfyPriorityDown = cfg.uptime-kuma.notifications.ntfy.priorityDown;
      };
      applyToAll = true;
    };
    statusPage = {
      enable = cfg.uptime-kuma.statusPage.enable;
      slug = cfg.uptime-kuma.statusPage.slug;
      title = cfg.uptime-kuma.statusPage.title;
      description = cfg.uptime-kuma.statusPage.description;
      isEntryPage = cfg.uptime-kuma.statusPage.isEntryPage;
      groups = cfg.uptime-kuma.statusPage.groups;
    };
  };

  syncConfigFile = pkgs.writeText "uptime-kuma-sync-config.json" (builtins.toJSON syncConfig);
in {
  options.server.uptime-kuma = {
    enable = mkOption {
      type = types.bool;
      default = false;
      description = "Enable Uptime Kuma monitoring and status page service.";
    };

    port = mkOption {
      type = types.port;
      default = 3001;
      description = "Internal HTTP port on which Uptime Kuma listens.";
    };

    subdomain = mkOption {
      type = types.str;
      default = "status";
      description = "Subdomain for Uptime Kuma (e.g. status.lukpac.dev).";
    };

    autoDiscover = mkOption {
      type = types.bool;
      default = true;
      description = "Automatically generate and sync monitors for all active services running on the server.";
    };

    gatewayIp = mkOption {
      type = types.str;
      default = "192.168.0.1";
      description = "LAN Gateway (Router) IP to ping for network health check.";
    };

    defaultNetworkMonitors = mkOption {
      type = types.bool;
      default = true;
      description = "Include default gateway ping and Internet (Cloudflare) ping monitors.";
    };

    cleanupUntrackedMonitors = mkOption {
      type = types.bool;
      default = true;
      description = "Remove monitors in Uptime Kuma that are not declared in NixOS configuration.";
    };

    notifications = {
      ntfy = {
        enable = mkOption {
          type = types.bool;
          default = cfg.notify.enable or false;
          description = "Automatically configure local Ntfy push notifications for all monitors.";
        };

        name = mkOption {
          type = types.str;
          default = "Haven Alerts";
          description = "Name of the notification provider in Uptime Kuma.";
        };

        serverUrl = mkOption {
          type = types.str;
          default = "http://127.0.0.1:${toString (cfg.notify.port or 2586)}";
          description = "URL of the Ntfy server.";
        };

        topic = mkOption {
          type = types.str;
          default = "alerts";
          description = "Ntfy topic to send notifications to.";
        };

        priority = mkOption {
          type = types.int;
          default = 4;
          description = "Default Ntfy priority (1-5).";
        };

        priorityDown = mkOption {
          type = types.int;
          default = 5;
          description = "Ntfy priority when a service goes down (1-5).";
        };
      };
    };

    statusPage = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = "Automatically provision default status page.";
      };

      slug = mkOption {
        type = types.str;
        default = "default";
        description = "Slug of the status page.";
      };

      title = mkOption {
        type = types.str;
        default = "Haven Status";
        description = "Title of the status page.";
      };

      description = mkOption {
        type = types.str;
        default = "Status aller Homelab-Dienste auf haven";
        description = "Description text displayed on the status page.";
      };

      isEntryPage = mkOption {
        type = types.bool;
        default = true;
        description = "Set status page as default landing page on root URL (/ statusPage-default).";
      };

      groups = mkOption {
        type = types.listOf types.str;
        default = [
          "Medien & Streaming"
          "Server & Cloud"
          "Netzwerk & Infrastruktur"
        ];
        description = "Ordered categories on the status page.";
      };
    };

    extraMonitors = mkOption {
      type = types.listOf (types.attrsOf types.anything);
      default = [];
      example = [
        {
          name = "External Website";
          type = "http";
          url = "https://example.com";
          interval = 60;
          group = "Server & Cloud";
        }
      ];
      description = "Additional custom monitors declared directly in Nix.";
    };

    sync = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = "Enable automatic SQLite synchronization on service startup.";
      };
    };
  };

  config = mkIf (cfg.enable && cfg.uptime-kuma.enable) {
    services.uptime-kuma = {
      enable = true;
      settings = {
        PORT = toString cfg.uptime-kuma.port;
        HOST = "127.0.0.1";
      };
    };

    # Declarative synchronization service
    systemd.services.uptime-kuma-sync = mkIf cfg.uptime-kuma.sync.enable {
      description = "Synchronize declarative configuration into Uptime Kuma";
      after = ["uptime-kuma.service"];
      wants = ["uptime-kuma.service"];
      wantedBy = ["multi-user.target"];
      restartTriggers = [syncConfigFile ./scripts/sync.py];

      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = "${pkgs.python3}/bin/python3 ${./scripts/sync.py} --db /var/lib/uptime-kuma/kuma.db --config ${syncConfigFile}";
      };
    };
  };
}
