{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (lib) mkOption mkIf mkDefault types;
  cfg = config.server.arr;
  inherit (import ../_lib.nix) secretRef;
in {
  options.server.arr.seerr = {
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

    subdomain = mkOption {
      type = types.str;
      default = "seerr";
      description = "Subdomain name for Seerr reverse proxy routing.";
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
        # REQUEST (32) + REQUEST_ADVANCED (16) + AUTO_APPROVE_MOVIE (64) + AUTO_APPROVE_TV (8) = 120
        # Automatically approves 1080p movie & TV requests within quota; 4K remains approval-required.
        defaultPermissions = 120;
        defaultQuotas = {
          movie = {
            quotaLimit = 3;
            quotaDays = 7;
          };
          tv = {
            quotaLimit = 1;
            quotaDays = 7;
          };
        };
      };

      # Movies manager - only configure if Radarr is enabled
      radarr.Radarr = mkIf cfg.radarr.enable {
        port = cfg.radarr.port;
        apiKey = secretRef config.sops.secrets.arr_radarr_api_key.path;
        activeProfileName = mkDefault "Full HD (1080p) – Englisch";
        activeDirectory = mkDefault cfg.paths.movies;
      };

      # Unified TV & Anime Series instance - only configure if Sonarr is enabled
      sonarr.Sonarr = mkIf cfg.sonarr.enable {
        port = cfg.sonarr.port;
        apiKey = secretRef config.sops.secrets.arr_sonarr_api_key.path;
        activeProfileName = mkDefault "Full HD (1080p) – Englisch";
        activeDirectory = mkDefault cfg.paths.tv;
        activeAnimeProfileName = mkDefault "Anime (1080p) – Japanisch (Sub)";
        activeAnimeDirectory = mkDefault cfg.paths.anime;
        animeSeriesType = mkDefault "anime";
      };

      # Optional dedicated Anime instance (disabled in unified mode)
      sonarr."Sonarr Anime" = mkIf (cfg.sonarr.enable && cfg.sonarr.anime.enable) {
        port = cfg.sonarr.anime.port;
        apiKey = secretRef config.sops.secrets.arr_sonarr_anime_api_key.path;
        activeProfileName = mkDefault "Anime (1080p) – Japanisch (Sub)";
        activeAnimeProfileName = mkDefault "Anime (1080p) – Japanisch (Sub)";
        animeSeriesType = mkDefault "anime";
        activeDirectory = mkDefault cfg.paths.anime;
        activeAnimeDirectory = mkDefault cfg.paths.anime;
      };
    };

    # Declarative ntfy webhook configuration for Jellyseerr
    systemd.services.seerr-notifications = mkIf (config.server.notify.enable or false) {
      description = "Configure Seerr ntfy webhook notifications";
      after = ["seerr-setup.service" "seerr.service"];
      requires = ["seerr-setup.service" "seerr.service"];
      wantedBy = ["multi-user.target"];

      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };

      script = let
        notifyPort = toString (config.server.notify.port or 2586);
        notifyTopic = config.server.notify.topic or "media";
        seerrDomain =
          if cfg.domain != null
          then "https://${cfg.seerr.subdomain}.${cfg.domain}"
          else "http://${config.networking.hostName}:${toString cfg.seerr.port}";
      in ''
        for i in $(seq 1 30); do
          if [ -f /run/seerr/api-key-header ]; then
            break
          fi
          sleep 1
        done

        ${pkgs.curl}/bin/curl -s -X POST \
          --header @"/run/seerr/api-key-header" \
          -H "Content-Type: application/json" \
          -d '{"enabled":true,"types":130,"options":{"webhookUrl":"http://127.0.0.1:${notifyPort}","jsonPayload":"{\"topic\":\"${notifyTopic}\",\"title\":\"🍿 Jellyseerr: {{subject}}\",\"message\":\"{{message}}\",\"click\":\"${seerrDomain}/requests\",\"actions\":[{\"action\":\"view\",\"label\":\"In Jellyseerr öffnen\",\"url\":\"${seerrDomain}/requests\"}]}"}}' \
          "http://127.0.0.1:${toString cfg.seerr.port}/api/v1/settings/notifications/webhook"
      '';
    };
  };
}
