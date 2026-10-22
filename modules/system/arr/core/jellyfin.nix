{
  config,
  pkgs,
  lib,
  ...
}: let
  inherit (lib) mkOption mkIf types optionals;
  cfg = config.arr;
  inherit (import ../_lib.nix) secretRef;

  jellyfinUser = "jellyfin";
in {
  # Options associated with jellyfin
  options.arr.jellyfin = {
    enable = mkOption {
      type = types.bool;
      default = true;
      description = "Enable Jellyfin media server.";
    };

    port = mkOption {
      type = types.port;
      default = 8096;
      description = "Port for Jellyfin web interface.";
    };

    subdomain = mkOption {
      type = types.str;
      default = "jellyfin";
      description = "Subdomain name for Jellyfin reverse proxy routing.";
    };

    adminUser = mkOption {
      type = types.str;
      default = cfg.adminUser;
      description = "Initial Jellyfin administrator username created by the setup wizard.";
    };

    hardwareAcceleration = mkOption {
      type = types.enum ["none" "qsv" "vaapi"];
      default = "none";
      description = "Hardware acceleration mode for Jellyfin transcoding.";
    };

    device = mkOption {
      type = types.str;
      default = "/dev/dri/renderD128";
      example = "/dev/dri/by-path/pci-0000:00:02.0-render";
      description = "Path to the DRM render node for hardware acceleration.";
    };

    realtimeMonitor = mkOption {
      type = types.bool;
      default = true;
      description = "Enable real-time filesystem monitoring (inotify) on Jellyfin media libraries so new downloads are detected immediately.";
    };
  };

  config = mkIf (cfg.enable && cfg.jellyfin.enable) {
    assertions = [
      {
        assertion = config.sops.secrets ? arr_jellyfin_admin_password;
        message = "arr.jellyfin: config.sops.secrets.arr_jellyfin_admin_password must be defined in your secrets file.";
      }
      {
        assertion = config.sops.secrets ? arr_jellyfin_api_key;
        message = "arr.jellyfin: config.sops.secrets.arr_jellyfin_api_key must be defined in your secrets file.";
      }
    ];

    hardware.graphics = mkIf (cfg.jellyfin.hardwareAcceleration != "none") {
      enable = true;
      extraPackages =
        [
          pkgs.intel-media-driver
          pkgs.intel-compute-runtime
        ]
        ++ optionals (cfg.jellyfin.hardwareAcceleration == "qsv") [
          pkgs.vpl-gpu-rt
        ];
    };

    users.users.${jellyfinUser}.extraGroups =
      mkIf (cfg.jellyfin.hardwareAcceleration != "none") ["video" "render"];

    sops.secrets.arr_jellyfin_admin_password.restartUnits = ["jellyfin.service"];
    sops.secrets.arr_jellyfin_api_key.restartUnits = ["jellyfin.service"];

    # add configuration to jellyfin via python script.
    systemd.services.jellyfin = let
      jellyfinSyncScript = pkgs.writeShellScript "jellyfin-sync-credentials" ''
        exec ${pkgs.python3}/bin/python3 ${../scripts/jellyfin-sync.py} \
          --pass-file "${config.sops.secrets.arr_jellyfin_admin_password.path}" \
          --key-file "${config.sops.secrets.arr_jellyfin_api_key.path}" \
          --admin-user "${cfg.jellyfin.adminUser}" \
          --media-group "${cfg.mediaGroup}"
      '';
    in {
      serviceConfig = {
        UMask = "0002";
        ExecStartPre = [
          "+${jellyfinSyncScript}"
        ];
      };
    };

    nixflix.jellyfin = {
      enable = true;
      user = jellyfinUser;
      group = cfg.mediaGroup;
      network.internalHttpPort = cfg.jellyfin.port;
      openFirewall = false;
      apiKey = secretRef config.sops.secrets.arr_jellyfin_api_key.path;

      users.${cfg.jellyfin.adminUser} = {
        policy.isAdministrator = true;
        password = secretRef config.sops.secrets.arr_jellyfin_admin_password.path;
      };

      libraries = {
        Movies = {
          collectionType = "movies";
          paths = [cfg.paths.movies];
          enableRealtimeMonitor = cfg.jellyfin.realtimeMonitor;
        };
        Shows = {
          enableRealtimeMonitor = cfg.jellyfin.realtimeMonitor;
        };
        Series = {
          collectionType = "tvshows";
          paths = [cfg.paths.tv];
          enableRealtimeMonitor = cfg.jellyfin.realtimeMonitor;
        };
        Anime = {
          collectionType = "tvshows";
          paths = [cfg.paths.anime];
          enableRealtimeMonitor = cfg.jellyfin.realtimeMonitor;
        };
      };

      # Optimal encoding configuration varies between devices - be careful.
      # Configuration for: 12th Gen Intel(R) Core(TM) i7-12700K
      encoding = {
        enableHardwareEncoding = cfg.jellyfin.hardwareAcceleration != "none";
        hardwareAccelerationType = cfg.jellyfin.hardwareAcceleration;
        vaapiDevice = cfg.jellyfin.device;
        qsvDevice = cfg.jellyfin.device;

        allowHevcEncoding = true;

        hardwareDecodingCodecs = [
          "h264"
          "hevc"
          "mpeg2video"
          "vc1"
          "vp8"
          "vp9"
          "av1"
        ];
        enableDecodingColorDepth10Hevc = true;
        enableDecodingColorDepth10Vp9 = true;

        enableIntelLowPowerH264HwEncoder = true;
        enableIntelLowPowerHevcHwEncoder = true;

        enableTonemapping = true;
        enableVppTonemapping = true;
      };
    };
  };
}
