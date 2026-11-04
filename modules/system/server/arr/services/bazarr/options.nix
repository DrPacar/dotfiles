{
  config,
  lib,
  ...
}: let
  inherit (lib) mkOption types;
  cfg = config.server.arr;
in {
  options.server.arr.bazarr = {
    enable = mkOption {
      type = types.bool;
      default = true;
      description = "Enable Bazarr subtitle manager.";
    };

    port = mkOption {
      type = types.port;
      default = 6767;
      description = "Port for Bazarr web interface.";
    };

    subdomain = mkOption {
      type = types.str;
      default = "bazarr";
      description = "Subdomain name for Bazarr reverse proxy routing.";
    };

    providers = mkOption {
      type = types.listOf types.str;
      default = [
        "animetosho"
        "embeddedsubtitles"
        "opensubtitlescom"
        "yifysubtitles"
      ];
      description = "Enabled subtitle providers for Bazarr searches.";
    };

    subsync = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = "Enable automated subtitle audio synchronization (subsync).";
      };

      autoUseOriginalLanguage = mkOption {
        type = types.bool;
        default = true;
        description = "Automatically select the video's original audio track for synchronization.";
      };

      useOriginalLanguage = mkOption {
        type = types.bool;
        default = true;
        description = "Use original language audio track for alignment.";
      };

      gss = mkOption {
        type = types.bool;
        default = true;
        description = "Use Golden Section Search algorithm for optimal subtitle timing synchronization.";
      };

      noFixFramerate = mkOption {
        type = types.bool;
        default = true;
        description = "Prevent subsync from altering or warping playback framerate.";
      };

      maxOffsetSeconds = mkOption {
        type = types.int;
        default = 60;
        description = "Maximum allowed timing offset in seconds during subtitle synchronization.";
      };
    };

    anime = {
      enable = mkOption {
        type = types.bool;
        default = cfg.sonarr.anime.enable;
        description = "Enable companion Bazarr Anime instance for dedicated anime subtitle management.";
      };

      port = mkOption {
        type = types.port;
        default = 6768;
        description = "Port for Bazarr Anime web interface.";
      };

      subdomain = mkOption {
        type = types.str;
        default = "bazarr-anime";
        description = "Subdomain name for Bazarr Anime reverse proxy routing.";
      };
    };
  };
}
