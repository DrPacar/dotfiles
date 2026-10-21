{
  config,
  lib,
  ...
}: let
  inherit (lib) mkOption mkIf mkDefault types;
  cfg = config.arr;
  inherit (import ../_lib.nix) secretRef;
in {
  options.arr.seerr = {
    enable = mkOption {
      type = types.bool;
      default = true;
      description = "Enable Seerr (Jellyseerr) media request interface.";
    };

    port = mkOption {
      type = types.port;
      default = 5055;
      description = "Port for Seerr web interface.";
    };
  };

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
      {
        assertion = !(cfg.sonarr.enable && cfg.sonarr.anime.enable) || config.sops.secrets ? arr_sonarr_anime_api_key;
        message = "arr.seerr: config.sops.secrets.arr_sonarr_anime_api_key must be defined when Sonarr Anime is enabled.";
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
        defaultPermissions = 32; # REQUEST only; admin approval needed.
      };

      # Movies manager - only configure if Radarr is enabled
      radarr.Radarr = mkIf cfg.radarr.enable {
        port = cfg.radarr.port;
        apiKey = secretRef config.sops.secrets.arr_radarr_api_key.path;
        activeProfileName = mkDefault "[SQP] SQP-1 (1080p)";
        activeDirectory = mkDefault cfg.paths.movies;
      };

      # TV Series instance - only configure if Sonarr is enabled
      sonarr.Sonarr = mkIf cfg.sonarr.enable {
        port = cfg.sonarr.port;
        apiKey = secretRef config.sops.secrets.arr_sonarr_api_key.path;
        activeProfileName = mkDefault "WEB-1080p (Alternative)";
        activeDirectory = mkDefault cfg.paths.tv;
      };

      # Anime instance - only configure if Sonarr Anime is enabled
      sonarr."Sonarr Anime" = mkIf (cfg.sonarr.enable && cfg.sonarr.anime.enable) {
        port = cfg.sonarr.anime.port;
        apiKey = secretRef config.sops.secrets.arr_sonarr_anime_api_key.path;
        activeProfileName = mkDefault "[Anime] Remux-1080p";
        activeDirectory = mkDefault cfg.paths.anime;
      };
    };
  };
}
