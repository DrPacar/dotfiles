{
  pkgs,
  lib,
  mod,
  ...
}: {
  imports =
    lib.concatMap mod [
      # applications
      "gaming"
      "virtualization"
      "kdeconnect"
      "server"

      # gui
      "gnome"
    ]
    ++ [
      ../base-packages.nix
    ];

  # Central Server Infrastructure & Services
  server = {
    enable = true;
    domain = "media.lukpac.dev";
    tailscaleDomain = "gute-court.ts.net";

    adguard = {
      enable = true;
      lanIp = "192.168.0.73";
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

    # Media automation stack (Arr Stack)
    arr = {
      enable = true;
      adminUser = "luka";
      dataDir = "/arr_data";
      mediaGid = 169;

      jellyfin = {
        hardwareAcceleration = "qsv"; # Enable Intel QuickSync hardware transcoding
        device = "/dev/dri/by-path/pci-0000:00:02.0-render";
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
        portForwarding.enable = true;
      };

      prowlarr = {
        indexers = [
          # Anime
          {name = "Nyaa.si";}
          {name = "SubsPlease";}

          # Movies & TV Shows
          {name = "YTS";}
          {name = "The Pirate Bay";}
          {name = "LimeTorrents";}
          {name = "TorrentDownload";}
        ];
      };

      backup.enable = false;
    };
  };

  # Declarative share access on lighthouse (direct local symlink ~/data -> /data)
  client.shares.data.enable = true;
}
