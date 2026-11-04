{
  config,
  pkgs,
  lib,
  ...
}: let
  inherit (lib) mkOption mkIf types optionals;
  cfg = config.server.arr;
  inherit (import ../_lib.nix) secretRef;

  jellyfinUser = "jellyfin";
in {
  # Options associated with jellyfin
  options.server.arr.jellyfin = {
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

    introSkipper = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = "Enable Intro Skipper plugin for automatic intro/outro detection and skip button in Jellyfin.";
      };
    };

    plugins = {
      playbackReporting = mkOption {
        type = types.bool;
        default = true;
        description = "Enable Playback Reporting plugin for watch statistics and dashboards.";
      };

      openSubtitles = mkOption {
        type = types.bool;
        default = true;
        description = "Enable OpenSubtitles plugin for on-the-fly subtitle searches in the player.";
      };

      tmdbBoxSets = mkOption {
        type = types.bool;
        default = true;
        description = "Enable TMDb Box Sets plugin to automatically group movie collections.";
      };

      animeMetadata = mkOption {
        type = types.bool;
        default = true;
        description = "Enable AniDB and AniList plugins for rich anime metadata.";
      };
    };

    theme = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = "Enable modern custom CSS theme for Jellyfin.";
      };

      customCss = mkOption {
        type = types.lines;
        default = ''@import url("https://cdn.jsdelivr.net/gh/lscambo13/ElegantFin@main/Theme/ElegantFin-jellyfin-theme-build-latest-minified.css");'';
        description = "Custom CSS to inject into Jellyfin web branding.";
      };
    };

    transcodingTempPath = mkOption {
      type = types.str;
      default = "/dev/shm/jellyfin-transcodes";
      description = "Directory for temporary transcode chunks (RAM-backed tmpfs recommended).";
    };

    hlsSegmentDuration = mkOption {
      type = types.int;
      default = 3;
      description = "Target HLS segment duration in seconds for rapid seeking and startup.";
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

    nixflix.jellyfin = let
      jellyfinFfmpegWrapped = pkgs.symlinkJoin {
        name = "jellyfin-ffmpeg-wrapped";
        paths = [
          (pkgs.writeShellScriptBin "ffmpeg" ''
            args=("$@")
            for ((i=0; i<''${#args[@]}; i++)); do
              if [ "''${args[i]}" = "-hls_time" ]; then
                ((i++))
                args[i]="${toString cfg.jellyfin.hlsSegmentDuration}"
              fi
            done
            exec ${pkgs.jellyfin-ffmpeg}/bin/ffmpeg "''${args[@]}"
          '')
          pkgs.jellyfin-ffmpeg
        ];
      };
    in {
      enable = true;
      user = jellyfinUser;
      group = cfg.mediaGroup;
      network.internalHttpPort = cfg.jellyfin.port;
      openFirewall = true;
      apiKey = secretRef config.sops.secrets.arr_jellyfin_api_key.path;

      users.${cfg.jellyfin.adminUser} = {
        policy = {
          isAdministrator = true;
          enableCollectionManagement = true;
        };
        password = secretRef config.sops.secrets.arr_jellyfin_admin_password.path;
        mutable = false;
        configuration = {
          displayCollectionsView = true;
          audioLanguagePreference = "ger";
          playDefaultAudioTrack = false;
          subtitleLanguagePreference = "ger";
          subtitleMode = "OnlyForced";
          rememberAudioSelections = true;
          rememberSubtitleSelections = true;
          enableNextEpisodeAutoPlay = true;
        };
      };

      system = {
        enableGroupingMoviesIntoCollections = true;
        trickplayOptions = {
          enableHwAcceleration = cfg.jellyfin.hardwareAcceleration != "none";
          enableHwEncoding = cfg.jellyfin.hardwareAcceleration != "none";
          processThreads = 2;
          processPriority = "BelowNormal";
          scanBehavior = "NonBlocking";
        };
      };

      plugins = {
        "Intro Skipper".enable = cfg.jellyfin.introSkipper.enable;
        "Playback Reporting".enable = cfg.jellyfin.plugins.playbackReporting;
        "Open Subtitles".enable = cfg.jellyfin.plugins.openSubtitles;
        "TMDb Box Sets".enable = cfg.jellyfin.plugins.tmdbBoxSets;
        "AniDB".enable = cfg.jellyfin.plugins.animeMetadata;
        "AniList".enable = cfg.jellyfin.plugins.animeMetadata;
      };

      branding = {
        customCss = mkIf cfg.jellyfin.theme.enable cfg.jellyfin.theme.customCss;
      };

      libraries = {
        Movies = {
          collectionType = "movies";
          paths = lib.mkForce [cfg.paths.movies];
          enableRealtimeMonitor = cfg.jellyfin.realtimeMonitor;
        };
        Shows = {
          collectionType = "tvshows";
          paths = lib.mkForce [cfg.paths.tv];
          enableRealtimeMonitor = cfg.jellyfin.realtimeMonitor;
        };
        Anime = {
          collectionType = "tvshows";
          paths = lib.mkForce [cfg.paths.anime];
          enableRealtimeMonitor = cfg.jellyfin.realtimeMonitor;
        };
      };

      # Optimal encoding configuration varies between devices - be careful.
      # Configuration for: Intel UHD Graphics 630 (Coffee Lake / 8th Gen)
      encoding = {
        transcodingTempPath = cfg.jellyfin.transcodingTempPath;
        encoderAppPathDisplay = "${jellyfinFfmpegWrapped}/bin/ffmpeg";

        enableHardwareEncoding = cfg.jellyfin.hardwareAcceleration != "none";
        hardwareAccelerationType = cfg.jellyfin.hardwareAcceleration;
        vaapiDevice = cfg.jellyfin.device;
        qsvDevice = cfg.jellyfin.device;

        allowHevcEncoding = false;

        hardwareDecodingCodecs = [
          "h264"
          "hevc"
          "mpeg2video"
          "vc1"
          "vp8"
          "vp9"
        ];
        enableDecodingColorDepth10Hevc = true;
        enableDecodingColorDepth10Vp9 = true;

        enableIntelLowPowerH264HwEncoder = false;
        enableIntelLowPowerHevcHwEncoder = false;

        enableTonemapping = true;
        enableVppTonemapping = true;
      };
    };
  };
}
