{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (lib) mkIf mkDefault;
  cfg = config.server.arr;
  inherit (import ../../_lib.nix) secretRef;

  mkExternalUrl = subdomain: port:
    if cfg.domain != null
    then "https://${subdomain}.${cfg.domain}"
    else if (config.server.domain or null) != null
    then "https://${subdomain}.${config.server.domain}"
    else "http://${config.networking.hostName}:${toString port}";
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
        externalHostname = mkDefault (mkExternalUrl cfg.jellyfin.subdomain cfg.jellyfin.port);
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
        externalUrl = mkDefault (mkExternalUrl cfg.radarr.subdomain cfg.radarr.port);
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
        externalUrl = mkDefault (mkExternalUrl cfg.sonarr.subdomain cfg.sonarr.port);
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

    systemd.services.seerr-env = {
      postStart = ''
        if [ -f "${config.sops.secrets.arr_seerr_api_key.path}" ]; then
          echo "X-Api-Key: $(cat "${config.sops.secrets.arr_seerr_api_key.path}")" > /run/seerr/api-key-header
          chown seerr:seerr /run/seerr/api-key-header
          chmod 0400 /run/seerr/api-key-header
        fi
      '';
    };

    systemd.services.seerr-setup.postStart = ''
      BASE_URL="http://127.0.0.1:${toString cfg.seerr.port}"
      API_KEY_FILE="${config.sops.secrets.arr_seerr_api_key.path}"
      APP_URL="${mkExternalUrl cfg.seerr.subdomain cfg.seerr.port}"
      if [ -f "$API_KEY_FILE" ]; then
        API_KEY=$(cat "$API_KEY_FILE")
        PAYLOAD=$(${pkgs.jq}/bin/jq -n --arg url "$APP_URL" '{applicationUrl: $url}')
        ${pkgs.curl}/bin/curl -sf -X POST \
          -H "X-Api-Key: $API_KEY" \
          -H "Content-Type: application/json" \
          -d "$PAYLOAD" \
          "$BASE_URL/api/v1/settings/main" >/dev/null || true
      fi
    '';

    systemd.services.seerr-sonarr = mkIf cfg.sonarr.enable {
      postStart = ''
        BASE_URL="http://127.0.0.1:${toString cfg.seerr.port}"
        API_KEY_FILE="${config.sops.secrets.arr_seerr_api_key.path}"
        if [ -f "$API_KEY_FILE" ]; then
          API_KEY=$(cat "$API_KEY_FILE")
          SERVERS=$(${pkgs.curl}/bin/curl -sf -H "X-Api-Key: $API_KEY" "$BASE_URL/api/v1/settings/sonarr" || true)
          if [ -n "$SERVERS" ]; then
            echo "$SERVERS" | ${pkgs.jq}/bin/jq -c ".[]" | while read -r server; do
              ID=$(echo "$server" | ${pkgs.jq}/bin/jq -r ".id")
              CURRENT=$(echo "$server" | ${pkgs.jq}/bin/jq -r ".monitorNewItems // empty")
              if [ "$CURRENT" != "none" ]; then
                echo "Setting monitorNewItems to none on Sonarr server $ID..."
                UPDATED=$(echo "$server" | ${pkgs.jq}/bin/jq "del(.id) | .monitorNewItems = \"none\"")
                ${pkgs.curl}/bin/curl -sf -X PUT \
                  -H "X-Api-Key: $API_KEY" \
                  -H "Content-Type: application/json" \
                  -d "$UPDATED" \
                  "$BASE_URL/api/v1/settings/sonarr/$ID" >/dev/null || true
              fi
            done
          fi
        fi
      '';
    };
  };
}
