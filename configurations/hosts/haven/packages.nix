{
  pkgs,
  lib,
  mod,
  ...
}: {
  imports = lib.concatMap mod [
    # shell & cli tools
    "base"

    # network & tailscale
    "network"

    # sops & age secrets
    "sops"

    # backup system
    "backup"

    # Central Server Infrastructure & Services
    "server"
  ];

  # Central Server Infrastructure & Services
  server = {
    enable = true;
    domain = "lukpac.dev";
    tailscaleDomain = "gute-court.ts.net";

    adguard = {
      enable = true;
      lanIp = "192.168.0.214";
    };

    vaultwarden = {
      enable = true;
    };

    openssh = {
      enable = true;
    };

    samba = {
      enable = true;
    };

    immich = {
      enable = true;
    };

    paperless = {
      enable = true;
    };

    uptime-kuma = {
      enable = true;
      subdomain = "status";
    };

    beszel = {
      enable = true;
      subdomain = "system";
    };

    notify = {
      enable = true;
      subdomain = "notify";
    };

    # Media automation stack (Arr Stack)
    arr = {
      enable = true;
      domain = "media.lukpac.dev";
      adminUser = "luka";
      dataDir = "/arr_data";
      mediaGid = 169;

      jellyfin = {
        hardwareAcceleration = "qsv";
        device = "/dev/dri/renderD128";
      };

      qbittorrent = {
        downloadRateLimitKiB = 25000;
        uploadRateLimitKiB = 3000;
        maxConnections = 100;
        maxConnectionsPerTorrent = 25;
        maxActiveDownloads = 2;
        maxActiveTorrents = 4;
        seedRatioLimit = 0.0;
      };

      vpn = {
        enable = true;
        portForwarding = {
          enable = true;
          gateway = "10.2.0.1";
        };
      };

      prowlarr = {
        indexers = [
          # Anime
          {
            name = "Nyaa.si";
            priority = 10;
            "torrentBaseSettings.appMinimumSeeders" = 3;
          }
          {
            name = "Anime Tosho";
            priority = 10;
            "torrentBaseSettings.appMinimumSeeders" = 3;
          }
          {
            name = "SubsPlease";
            priority = 15;
            "torrentBaseSettings.appMinimumSeeders" = 3;
          }
          {
            name = "Tokyo Toshokan";
            priority = 15;
            "torrentBaseSettings.appMinimumSeeders" = 3;
          }
          {
            name = "Shana Project";
            priority = 15;
            "torrentBaseSettings.appMinimumSeeders" = 3;
          }

          # Movies & TV Shows
          {
            name = "EZTV";
            priority = 20;
            tags = ["flaresolverr"];
            "torrentBaseSettings.appMinimumSeeders" = 3;
          }
          {
            name = "kickasstorrents.to";
            priority = 25;
            tags = ["flaresolverr"];
            "torrentBaseSettings.appMinimumSeeders" = 3;
          }
          {
            name = "The Pirate Bay";
            priority = 25;
            "torrentBaseSettings.appMinimumSeeders" = 3;
          }
          {
            name = "LimeTorrents";
            priority = 30;
            "torrentBaseSettings.appMinimumSeeders" = 3;
          }
          {
            name = "TorrentDownload";
            priority = 30;
            "torrentBaseSettings.appMinimumSeeders" = 3;
          }
        ];
      };

      backup.enable = false;
    };
  };

  # Declarative share access on haven (direct local symlink ~/data -> /data)
  client.shares.data = {
    enable = true;
    serverHost = "haven";
  };
}
