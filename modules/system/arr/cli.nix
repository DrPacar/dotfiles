{
  config,
  pkgs,
  lib,
  ...
}: let
  inherit (lib) mkOption mkIf types;
  cfg = config.arr;

  arrConfigJson = pkgs.writeText "arr-config.json" (builtins.toJSON {
    dataDir = cfg.dataDir;
    tailscaleDomain = cfg.tailscaleDomain;
    paths = cfg.paths;
    resources = {
      enable = cfg.resources.enable;
      cpuWeight = cfg.resources.cpuWeight;
      ioWeight = cfg.resources.ioWeight;
      memoryHigh = cfg.resources.memoryHigh;
    };
    backup = {
      enable = cfg.backup.enable;
      destDir = cfg.backup.destDir;
      calendar = cfg.backup.calendar;
      retentionDays = cfg.backup.retentionDays;
    };
    services = {
      jellyfin = {
        enable = cfg.jellyfin.enable;
        port = cfg.jellyfin.port;
        unit = "jellyfin.service";
      };
      qbittorrent = {
        enable = cfg.qbittorrent.enable;
        port = cfg.qbittorrent.webuiPort;
        unit = "qbittorrent.service";
      };
      radarr = {
        enable = cfg.radarr.enable;
        port = cfg.radarr.port;
        unit = "radarr.service";
      };
      sonarr = {
        enable = cfg.sonarr.enable;
        port = cfg.sonarr.port;
        unit = "sonarr.service";
      };
      sonarr-anime = {
        enable = cfg.sonarr.enable && cfg.sonarr.anime.enable;
        port = cfg.sonarr.anime.port;
        unit = "sonarr-anime.service";
      };
      prowlarr = {
        enable = cfg.prowlarr.enable;
        port = cfg.prowlarr.port;
        unit = "prowlarr.service";
      };
      bazarr = {
        enable = cfg.bazarr.enable;
        port = cfg.bazarr.port;
        unit = "bazarr.service";
      };
      seerr = {
        enable = cfg.seerr.enable;
        port = cfg.seerr.port;
        unit = "seerr.service";
      };
      flaresolverr = {
        enable = cfg.flaresolverr.enable;
        port = cfg.flaresolverr.port;
        unit = "flaresolverr.service";
      };
      recyclarr = {
        enable = cfg.recyclarr.enable && (cfg.radarr.enable || cfg.sonarr.enable);
        unit = "recyclarr.service";
      };
      vpn = {
        enable = cfg.vpn.enable;
        portForwarding = cfg.vpn.portForwarding.enable;
        namespace = cfg.vpn.namespace;
        unit = "${cfg.vpn.namespace}.service";
        proxyUnit = "qbittorrent-webui-proxy.service";
        forwarderUnit = "protonvpn-port-forward.service";
      };
    };
  });

  pythonEnv = pkgs.python3.withPackages (ps: [
    ps.rich
  ]);

  arrStatusPkg = pkgs.writeShellApplication {
    name = "arr-status";
    runtimeInputs = [
      pythonEnv
      pkgs.systemd
      pkgs.coreutils
    ];
    text = ''
      exec python3 ${./scripts/arr-status.py} --config "${arrConfigJson}" "$@"
    '';
  };

  # Multi-tool CLI dispatcher
  arrCliPkg = pkgs.writeShellApplication {
    name = "arr";
    runtimeInputs = [
      arrStatusPkg
      pkgs.systemd
    ];
    text = ''
      case "''${1:-status}" in
        status)
          shift || true
          exec arr-status "$@"
          ;;
        backup)
          ${
        if cfg.backup.enable
        then ''
          echo "Triggering arr-backup.service..."
          exec systemctl start arr-backup.service
        ''
        else ''
          echo "Error: arr.backup is disabled in your NixOS configuration."
          echo "Enable arr.backup.enable = true to use automated backups."
          exit 1
        ''
      }
          ;;
        logs)
          shift || true
          svc="''${1:-sonarr}"
          svc="''${svc%.service}"
          case "$svc" in
            jellyseerr) svc="seerr" ;;
            qbit) svc="qbittorrent" ;;
            anime) svc="sonarr-anime" ;;
            indexer) svc="prowlarr" ;;
            subtitles) svc="bazarr" ;;
            vpn) svc="${cfg.vpn.namespace}" ;;
            proxy) svc="qbittorrent-webui-proxy" ;;
            forwarder|natpmp) svc="protonvpn-port-forward" ;;
          esac
          exec journalctl -u "''${svc}.service" -f
          ;;
        restart)
          shift || true
          if [[ -z "''${1:-}" ]]; then
            echo "Usage: arr restart <service-name>"
            exit 1
          fi
          svc="''${1%.service}"
          case "$svc" in
            jellyseerr) svc="seerr" ;;
            qbit) svc="qbittorrent" ;;
            anime) svc="sonarr-anime" ;;
            indexer) svc="prowlarr" ;;
            subtitles) svc="bazarr" ;;
            vpn) svc="${cfg.vpn.namespace}" ;;
            proxy) svc="qbittorrent-webui-proxy" ;;
            forwarder|natpmp) svc="protonvpn-port-forward" ;;
          esac
          exec systemctl restart "''${svc}.service"
          ;;
        help|--help|-h)
          echo "Arr Stack Management CLI"
          echo ""
          echo "Usage: arr [command]"
          echo ""
          echo "Commands:"
          echo "  status         Display comprehensive stack status (default, aliases: arr-status)"
          echo "  status -w      Continuously watch stack status"
          echo "  status --json  Output raw JSON for scripts/monitoring"
          echo "  backup         Trigger on-demand backup via arr-backup.service"
          echo "  logs <svc>     Follow journal logs for a service (e.g., arr logs sonarr)"
          echo "  restart <svc>  Restart a service (e.g., arr restart radarr)"
          ;;
        *)
          exec arr-status "$@"
          ;;
      esac
    '';
  };
in {
  options.arr.cli = {
    enable = mkOption {
      type = types.bool;
      default = true;
      example = false;
      description = "Whether to install the arr-status and arr CLI utilities in environment.systemPackages.";
    };
  };

  config = mkIf (cfg.enable && cfg.cli.enable) {
    environment.systemPackages = [
      arrStatusPkg
      arrCliPkg
    ];
  };
}
