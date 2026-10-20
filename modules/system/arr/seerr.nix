{
  config,
  lib,
  ...
}: let
  inherit (lib) mkOption mkIf mkDefault types;
  cfg = config.arr;
  inherit (import ./_lib.nix) secretRef;
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
    nixflix.seerr = {
      enable = true;
      port = cfg.seerr.port;
      openFirewall = false;
      apiKey = secretRef config.sops.secrets.arr_seerr_api_key.path;

      jellyfin = {
        adminUsername = cfg.jellyfin.adminUser;
        adminPassword = secretRef config.sops.secrets.arr_jellyfin_admin_password.path;
      };

      settings.users = {
        defaultPermissions = 32; # REQUEST only; admin approval needed.
      };

      # Movies manager
      radarr.Radarr = {
        port = cfg.radarr.port;
        apiKey = secretRef config.sops.secrets.arr_radarr_api_key.path;
        activeProfileName = mkDefault "[SQP] SQP-1 (1080p)";
        activeDirectory = mkDefault "${cfg.dataDir}/media/movies";
      };

      # TV Series instance
      sonarr.Sonarr = {
        port = cfg.sonarr.port;
        apiKey = secretRef config.sops.secrets.arr_sonarr_api_key.path;
        activeProfileName = mkDefault "WEB-1080p (Alternative)";
        activeDirectory = mkDefault "${cfg.dataDir}/media/tv";
      };

      # Anime instance
      sonarr."Sonarr Anime" = mkIf cfg.sonarr.anime.enable {
        port = cfg.sonarr.anime.port;
        apiKey = secretRef config.sops.secrets.arr_sonarr_anime_api_key.path;
        activeProfileName = mkDefault "[Anime] Remux-1080p";
        activeDirectory = mkDefault "${cfg.dataDir}/media/anime";
      };
    };
  };
}
