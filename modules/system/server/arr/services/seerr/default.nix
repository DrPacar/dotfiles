{
  config,
  lib,
  ...
}: let
  inherit (lib) mkIf mkDefault;
  cfg = config.server.arr;
  inherit (import ../../_lib.nix) secretRef;
in {
  config = mkIf (cfg.enable && cfg.seerr.enable) {
    warnings = lib.optional (!cfg.jellyfin.enable) "arr.seerr: Jellyseerr uses Jellyfin as its authentication backend. If local Jellyfin is disabled, ensure you connect an external Jellyfin server in the Seerr setup wizard.";

    assertions = [
      {
        assertion = config.sops.secrets ? arr_seerr_api_key;
        message = "arr.seerr: config.sops.secrets.arr_seerr_api_key must be defined in your secrets file.";
      }
      {
        assertion = !cfg.jellyfin.enable || cfg.adminPasswordFile != null;
        message = "arr.seerr: arr.adminPasswordFile must be set to connect Seerr with Jellyfin.";
      }
      {
        assertion = !cfg.radarr.enable || config.sops.secrets ? arr_radarr_api_key;
        message = "arr.seerr: config.sops.secrets.arr_radarr_api_key must be defined when Radarr is enabled.";
      }
      {
        assertion = !cfg.sonarr.enable || config.sops.secrets ? arr_sonarr_api_key;
        message = "arr.seerr: config.sops.secrets.arr_sonarr_api_key must be defined when Sonarr is enabled.";
      }
    ];

    nixflix.seerr = {
      enable = true;
      port = cfg.seerr.port;
      openFirewall = false;
      apiKey = secretRef config.sops.secrets.arr_seerr_api_key.path;

      jellyfin = mkIf cfg.jellyfin.enable {
        adminUsername = cfg.adminUser;
        adminPassword = secretRef cfg.adminPasswordFile;
      };

      settings.users = {
        defaultPermissions = cfg.seerr.defaultPermissions;
        defaultQuotas = {
          movie = {
            quotaLimit = cfg.seerr.defaultQuotas.movie.quotaLimit;
            quotaDays = cfg.seerr.defaultQuotas.movie.quotaDays;
          };
          tv = {
            quotaLimit = cfg.seerr.defaultQuotas.tv.quotaLimit;
            quotaDays = cfg.seerr.defaultQuotas.tv.quotaDays;
          };
        };
      };

      # Movies manager - only configure if Radarr is enabled
      radarr.Radarr = mkIf cfg.radarr.enable {
        port = cfg.radarr.port;
        apiKey = secretRef config.sops.secrets.arr_radarr_api_key.path;
        activeProfileName = mkDefault cfg.seerr.defaultMovieProfile;
        activeDirectory = mkDefault cfg.paths.movies;
      };

      # Unified TV & Anime Series instance - only configure if Sonarr is enabled
      sonarr.Sonarr = mkIf cfg.sonarr.enable {
        port = cfg.sonarr.port;
        apiKey = secretRef config.sops.secrets.arr_sonarr_api_key.path;
        activeProfileName = mkDefault cfg.seerr.defaultSeriesProfile;
        activeDirectory = mkDefault cfg.paths.tv;
        activeAnimeProfileName = mkDefault cfg.seerr.defaultAnimeProfile;
        activeAnimeDirectory = mkDefault cfg.paths.anime;
        animeSeriesType = mkDefault "anime";
      };
    };

    systemd.services.seerr = {
      serviceConfig = {
        Slice = "arr.slice";
        MemoryHigh = "768M";
        MemoryMax = "1200M";
        Restart = "on-failure";
        RestartSec = 15;
      };
    };
  };
}
