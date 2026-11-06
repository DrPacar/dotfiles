{
  config,
  lib,
  ...
}: let
  inherit (lib) mkOption types;
  cfg = config.server.arr;

  userSubmodule = types.submodule {
    options = {
      isAdmin = mkOption {
        type = types.bool;
        default = false;
        description = "Grant administrator privileges to this user.";
      };

      passwordSecret = mkOption {
        type = types.nullOr types.path;
        default = null;
        description = "Path to SOPS secret containing the user password.";
      };

      mutable = mkOption {
        type = types.bool;
        default = false;
        description = ''
          If false, Jellyfin configuration options defined in Nix will overwrite GUI changes upon rebuild.
          If true, initial options are applied, but changes made in the web UI will take priority and won't be overwritten.
        '';
      };

      audioLanguage = mkOption {
        type = types.str;
        default = "ger";
        description = "Preferred audio language code (ISO 639-2/B, e.g. ger, eng).";
      };

      subtitleLanguage = mkOption {
        type = types.str;
        default = "ger";
        description = "Preferred subtitle language code (ISO 639-2/B, e.g. ger, eng).";
      };

      subtitleMode = mkOption {
        type = types.enum ["Default" "Always" "OnlyForced" "None" "Smart"];
        default = "OnlyForced";
        description = "Subtitle playback behavior.";
      };

      enableNextEpisodeAutoPlay = mkOption {
        type = types.bool;
        default = true;
        description = "Automatically play next episode in a series.";
      };

      rememberAudioSelections = mkOption {
        type = types.bool;
        default = true;
        description = "Remember audio track selection for subsequent playback.";
      };

      rememberSubtitleSelections = mkOption {
        type = types.bool;
        default = true;
        description = "Remember subtitle track selection for subsequent playback.";
      };

      displayCollectionsView = mkOption {
        type = types.bool;
        default = true;
        description = "Display collections view in the user's home screen.";
      };

      enableMediaPlayback = mkOption {
        type = types.bool;
        default = true;
        description = "Allow user to play media.";
      };

      enableAudioPlaybackTranscoding = mkOption {
        type = types.bool;
        default = true;
        description = "Allow audio transcoding if client cannot direct-play.";
      };

      enableVideoPlaybackTranscoding = mkOption {
        type = types.bool;
        default = true;
        description = "Allow video transcoding if client cannot direct-play.";
      };

      enablePlaybackRemuxing = mkOption {
        type = types.bool;
        default = true;
        description = "Allow remuxing container format without re-encoding.";
      };

      enableContentDeletion = mkOption {
        type = types.bool;
        default = false;
        description = "Allow user to delete media files from the filesystem.";
      };

      enableContentDownloading = mkOption {
        type = types.bool;
        default = true;
        description = "Allow user to download media files for offline playback.";
      };
    };
  };

  customLibrarySubmodule = types.submodule {
    options = {
      collectionType = mkOption {
        type = types.enum [
          "movies"
          "tvshows"
          "music"
          "musicvideos"
          "homevideos"
          "boxsets"
          "books"
          "mixed"
        ];
        description = "Type of media library.";
      };

      paths = mkOption {
        type = types.listOf types.str;
        description = "Filesystem paths for this library.";
      };

      enableRealtimeMonitor = mkOption {
        type = types.bool;
        default = true;
        description = "Monitor filesystem changes in real-time.";
      };
    };
  };
in {
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
      description = "Enable real-time filesystem monitoring (inotify) on Jellyfin media libraries.";
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

    introSkipper = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = "Enable Intro Skipper plugin for automatic intro/outro detection and skip button.";
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

      simkl = mkOption {
        type = types.bool;
        default = true;
        description = "Enable Simkl plugin for watch history tracking and scrobbling.";
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

    branding = {
      loginDisclaimer = mkOption {
        type = types.lines;
        default = "";
        description = "Text shown during login underneath the credentials form.";
      };

      splashscreenEnabled = mkOption {
        type = types.bool;
        default = false;
        description = "Enables a splashscreen image to be shown during loading.";
      };

      splashscreenLocation = mkOption {
        type = types.nullOr (types.either types.path types.str);
        default = null;
        description = "Location of splashscreen image (16:9 aspect ratio, min 1920x1080).";
      };
    };

    users = mkOption {
      type = types.attrsOf userSubmodule;
      default = {};
      description = "Declarative Jellyfin user accounts, permissions, and preferences.";
    };

    libraries = {
      saveLocalMetadata = mkOption {
        type = types.bool;
        default = true;
        description = "Save metadata (.nfo files and artwork) alongside media files.";
      };

      enablePhotos = mkOption {
        type = types.bool;
        default = true;
        description = "Enable photo support in libraries.";
      };

      enableLUFSScan = mkOption {
        type = types.bool;
        default = true;
        description = "Enable LUFS audio loudness normalization scanning.";
      };

      enableChapterImageExtraction = mkOption {
        type = types.bool;
        default = true;
        description = "Extract chapter thumbnails from video files.";
      };

      extractChapterImagesDuringLibraryScan = mkOption {
        type = types.bool;
        default = false;
        description = "Extract chapter images during full library scans instead of on-demand.";
      };

      enableTrickplayImageExtraction = mkOption {
        type = types.bool;
        default = true;
        description = "Extract trickplay scrubbing images (timeline thumbnail preview).";
      };

      extractTrickplayImagesDuringLibraryScan = mkOption {
        type = types.bool;
        default = false;
        description = "Extract trickplay scrubbing images during library scans instead of on-demand.";
      };

      animeMetadataPriority = mkOption {
        type = types.listOf types.str;
        default = [
          "AniDB"
          "AniList"
          "TheMovieDb"
          "The Open Movie Database"
        ];
        description = "Metadata fetcher order for Anime series and episodes.";
      };

      moviesMetadataPriority = mkOption {
        type = types.listOf types.str;
        default = [
          "TheMovieDb"
          "The Open Movie Database"
        ];
        description = "Metadata fetcher order for Movies.";
      };

      showsMetadataPriority = mkOption {
        type = types.listOf types.str;
        default = [
          "TheMovieDb"
          "The Open Movie Database"
        ];
        description = "Metadata fetcher order for TV Shows.";
      };

      custom = mkOption {
        type = types.attrsOf customLibrarySubmodule;
        default = {};
        description = "Extra declarative media libraries beyond Movies, Shows, and Anime.";
      };
    };

    encoding = {
      allowHevcEncoding = mkOption {
        type = types.bool;
        default = false;
        description = "Allow encoding transcoded streams into HEVC (H.265).";
      };

      allowAv1Encoding = mkOption {
        type = types.bool;
        default = false;
        description = "Allow encoding transcoded streams into AV1.";
      };

      hardwareDecodingCodecs = mkOption {
        type = types.listOf types.str;
        default = [
          "h264"
          "hevc"
          "mpeg2video"
          "vc1"
          "vp8"
          "vp9"
        ];
        description = "Video codecs that should be decoded using hardware acceleration.";
      };

      enableDecodingColorDepth10Hevc = mkOption {
        type = types.bool;
        default = true;
        description = "Enable 10-bit color depth hardware decoding for HEVC.";
      };

      enableDecodingColorDepth10Vp9 = mkOption {
        type = types.bool;
        default = true;
        description = "Enable 10-bit color depth hardware decoding for VP9.";
      };

      enableLowPowerH264Encoder = mkOption {
        type = types.bool;
        default = false;
        description = "Enable Intel low power hardware encoder for H.264.";
      };

      enableLowPowerHevcEncoder = mkOption {
        type = types.bool;
        default = false;
        description = "Enable Intel low power hardware encoder for HEVC.";
      };

      enableTonemapping = mkOption {
        type = types.bool;
        default = true;
        description = "Enable HDR tone-mapping algorithm.";
      };

      enableVppTonemapping = mkOption {
        type = types.bool;
        default = true;
        description = "Enable Intel VPP tone-mapping (hardware-accelerated HDR to SDR conversion).";
      };

      encodingThreadCount = mkOption {
        type = types.int;
        default = -1;
        description = "Number of threads used for encoding (-1 for auto, 0 for maximum).";
      };
    };

    system = {
      enableGroupingMoviesIntoCollections = mkOption {
        type = types.bool;
        default = true;
        description = "Automatically group movie sequels and series into box set collections.";
      };

      trickplay = {
        processThreads = mkOption {
          type = types.int;
          default = 2;
          description = "CPU threads allocated for trickplay thumbnail generation.";
        };

        processPriority = mkOption {
          type = types.enum ["High" "AboveNormal" "Normal" "BelowNormal" "Idle"];
          default = "BelowNormal";
          description = "Process priority for ffmpeg trickplay extraction.";
        };

        scanBehavior = mkOption {
          type = types.enum ["NonBlocking" "Blocking"];
          default = "NonBlocking";
          description = "Scan behavior for trickplay images.";
        };

        interval = mkOption {
          type = types.int;
          default = 10000;
          description = "Interval in milliseconds between each extracted thumbnail image.";
        };

        widthResolutions = mkOption {
          type = types.listOf types.int;
          default = [320];
          description = "Widths in pixels for generated trickplay tiles.";
        };

        tileWidth = mkOption {
          type = types.int;
          default = 10;
          description = "Number of thumbnails per tile horizontally.";
        };

        tileHeight = mkOption {
          type = types.int;
          default = 10;
          description = "Number of thumbnails per tile vertically.";
        };

        qscale = mkOption {
          type = types.ints.between 2 31;
          default = 4;
          description = "Quality scale for ffmpeg tile extraction (2 = highest, 31 = lowest).";
        };

        jpegQuality = mkOption {
          type = types.ints.between 0 100;
          default = 90;
          description = "JPEG compression quality percentage for trickplay images.";
        };
      };
    };
  };
}
