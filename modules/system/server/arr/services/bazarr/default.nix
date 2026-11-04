{
  config,
  lib,
  ...
}: let
  inherit (lib) mkIf;
  cfg = config.server.arr;
  inherit (import ../../_lib.nix) secretRef;

  bazarrUser = "bazarr";
  animeEnabled = cfg.bazarr.anime.enable && cfg.sonarr.anime.enable;

  commonOpenSubtitles = {
    username = secretRef config.sops.secrets.arr_opensubtitles_username.path;
    password = secretRef config.sops.secrets.arr_opensubtitles_password.path;
    use_hash = true;
    include_ai_translated = false;
    include_machine_translated = false;
  };

  commonSubsync = {
    use_subsync = cfg.bazarr.subsync.enable;
    auto_use_original_language = cfg.bazarr.subsync.autoUseOriginalLanguage;
    use_original_language = cfg.bazarr.subsync.useOriginalLanguage;
    gss = cfg.bazarr.subsync.gss;
    no_fix_framerate = cfg.bazarr.subsync.noFixFramerate;
    max_offset_seconds = cfg.bazarr.subsync.maxOffsetSeconds;
  };
in {
  config = mkIf (cfg.enable && cfg.bazarr.enable) {
    assertions = [
      {
        assertion = config.sops.secrets ? arr_bazarr_api_key;
        message = "arr.bazarr: config.sops.secrets.arr_bazarr_api_key must be defined in your secrets file.";
      }
      {
        assertion = !cfg.sonarr.enable || config.sops.secrets ? arr_sonarr_api_key;
        message = "arr.bazarr: config.sops.secrets.arr_sonarr_api_key must be defined when Sonarr is enabled.";
      }
      {
        assertion = !animeEnabled || config.sops.secrets ? arr_sonarr_anime_api_key;
        message = "arr.bazarr.anime: config.sops.secrets.arr_sonarr_anime_api_key must be defined when Bazarr Anime is enabled.";
      }
      {
        assertion = !cfg.radarr.enable || config.sops.secrets ? arr_radarr_api_key;
        message = "arr.bazarr: config.sops.secrets.arr_radarr_api_key must be defined when Radarr is enabled.";
      }
      {
        assertion = !cfg.jellyfin.enable || config.sops.secrets ? arr_jellyfin_api_key;
        message = "arr.bazarr: config.sops.secrets.arr_jellyfin_api_key must be defined when Jellyfin is enabled.";
      }
      {
        assertion = !cfg.bazarr.enable || config.sops.secrets ? arr_opensubtitles_username;
        message = "arr.bazarr: config.sops.secrets.arr_opensubtitles_username must be defined in your secrets file.";
      }
      {
        assertion = !cfg.bazarr.enable || config.sops.secrets ? arr_opensubtitles_password;
        message = "arr.bazarr: config.sops.secrets.arr_opensubtitles_password must be defined in your secrets file.";
      }
    ];

    # Subtitle file permissions & systemd service hardening
    systemd.services.bazarr.serviceConfig = {
      UMask = "0002"; # rw-rw-r-- (group-writable for media group)
      Slice = "arr.slice";
      MemoryHigh = "1G";
      MemoryMax = "1.5G";
      Restart = "on-failure";
      RestartSec = 15;
    };

    sops.secrets.arr_jellyfin_api_key.restartUnits = mkIf cfg.jellyfin.enable (
      ["bazarr.service"]
      ++ lib.optional animeEnabled "bazarr-anime.service"
    );

    # =========================================================================
    # Standard Bazarr Instance (Port 6767) - TV Shows & Movies
    # =========================================================================
    services.bazarr = {
      enable = true;
      user = bazarrUser;
      group = cfg.mediaGroup;
      openFirewall = false;

      settings = {
        general = {
          ip = cfg.network.bindAddress;
          port = cfg.bazarr.port;
          instance_name = "Bazarr";
          use_sonarr = cfg.sonarr.enable;
          use_radarr = cfg.radarr.enable;
          use_jellyfin = cfg.jellyfin.enable;
          enabled_providers = cfg.bazarr.providers;
          movie_default_enabled = true;
          movie_default_profile = 1;
          serie_default_enabled = true;
          serie_default_profile = 1;

          # Optimized subtitle filesystem handling & encoding
          chmod = "0664";
          chmod_enabled = true;
          subfolder = "current";
          utf8_encode = true;
          adaptive_searching = true;
          use_embedded_subs = true;
          embedded_subtitles_parser = "ffprobe";
          parse_embedded_audio_track = true;
          upgrade_subs = true;
          upgrade_frequency = 12;
          days_to_upgrade_subs = 7;
          minimum_score = 90;
          minimum_score_movie = 70;
        };

        opensubtitlescom = commonOpenSubtitles;
        subsync = commonSubsync;

        auth = {
          apikey = secretRef config.sops.secrets.arr_bazarr_api_key.path;
        };

        sonarr = mkIf cfg.sonarr.enable {
          ip = cfg.network.localAddress;
          port = cfg.sonarr.port;
          apikey = secretRef config.sops.secrets.arr_sonarr_api_key.path;
          ssl = false;
          base_url = "";
        };

        radarr = mkIf cfg.radarr.enable {
          ip = cfg.network.localAddress;
          port = cfg.radarr.port;
          apikey = secretRef config.sops.secrets.arr_radarr_api_key.path;
          ssl = false;
          base_url = "";
        };

        jellyfin = mkIf cfg.jellyfin.enable {
          ip = cfg.network.localAddress;
          port = cfg.jellyfin.port;
          ssl = false;
          url = "http://${cfg.network.localAddress}:${toString cfg.jellyfin.port}";
          apikey = secretRef config.sops.secrets.arr_jellyfin_api_key.path;
          update_movie_library = true;
          update_series_library = true;
          movie_library = ["Movies"];
          movie_library_ids = ["f137a2dd21bbc1b99aa5c0f6bf02a805"];
          series_library = ["Anime" "Shows"];
          series_library_ids = [
            "0c41907140d802bb58430fed7e2cd79e"
            "a656b907eb3a73532e40e44b968d0225"
          ];
          refresh_method = "immediate";
        };
      };
    };
  };
}
