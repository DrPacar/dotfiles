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
      "arr"

      # gui
      "gnome"
    ]
    ++ [
      ../base-packages.nix
    ];
  # Media automation stack (Arr Stack)
  arr = {
    enable = true;
    adminUser = "luka";
    dataDir = "/arr_data";
    mediaGid = 169;
    tailscaleDomain = "gute-court.ts.net";
    domain = "media.lukpac.dev";

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
}
