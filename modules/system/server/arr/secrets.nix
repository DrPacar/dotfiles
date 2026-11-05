{
  config,
  lib,
  ...
}: let
  inherit (lib) mkIf;
  cfg = config.server.arr;
in {
  config = mkIf cfg.enable {
    # -------------------------------------------------------------------------
    # Secrets Permissions & Automatic Service Synchronization
    # -------------------------------------------------------------------------
    sops.secrets = lib.mkMerge [
      (lib.genAttrs (
          lib.optional cfg.sonarr.enable "arr_sonarr_api_key"
          ++ lib.optional cfg.radarr.enable "arr_radarr_api_key"
          ++ lib.optional cfg.prowlarr.enable "arr_prowlarr_api_key"
          ++ lib.optional cfg.bazarr.enable "arr_bazarr_api_key"
          ++ lib.optional (cfg.bazarr.enable || cfg.jellyfin.enable) "arr_opensubtitles_username"
          ++ lib.optional (cfg.bazarr.enable || cfg.jellyfin.enable) "arr_opensubtitles_password"
          ++ lib.optional cfg.seerr.enable "arr_seerr_api_key"
          ++ lib.optional cfg.jellyfin.enable "arr_jellyfin_api_key"
          ++ ["services_password"]
        ) (_name: {
          group = lib.mkForce cfg.mediaGroup;
          mode = lib.mkForce "0440";
        }))
      (lib.optionalAttrs cfg.vpn.enable {
        arr_wireguard_conf = {
          mode = lib.mkForce "0400";
          restartUnits = ["${cfg.vpn.namespace}.service"];
        };
      })
      (lib.optionalAttrs cfg.sonarr.enable {
        arr_sonarr_api_key.restartUnits =
          lib.optional cfg.sonarr.enable "sonarr-config.service"
          ++ lib.optional (cfg.prowlarr.enable && cfg.sonarr.enable) "prowlarr-applications.service"
          ++ lib.optional (cfg.seerr.enable && cfg.sonarr.enable) "seerr-sonarr.service"
          ++ lib.optional (cfg.bazarr.enable && cfg.sonarr.enable) "bazarr.service";
      })
      (lib.optionalAttrs cfg.radarr.enable {
        arr_radarr_api_key.restartUnits =
          lib.optional cfg.radarr.enable "radarr-config.service"
          ++ lib.optional (cfg.prowlarr.enable && cfg.radarr.enable) "prowlarr-applications.service"
          ++ lib.optional (cfg.seerr.enable && cfg.radarr.enable) "seerr-radarr.service"
          ++ lib.optional (cfg.bazarr.enable && cfg.radarr.enable) "bazarr.service";
      })
      (lib.optionalAttrs cfg.prowlarr.enable {
        arr_prowlarr_api_key.restartUnits =
          lib.optional cfg.prowlarr.enable "prowlarr-config.service"
          ++ lib.optional cfg.prowlarr.enable "prowlarr-applications.service";
      })
      (lib.optionalAttrs cfg.seerr.enable {
        arr_seerr_api_key.restartUnits =
          lib.optional cfg.seerr.enable "seerr.service"
          ++ lib.optional (cfg.seerr.enable && cfg.sonarr.enable) "seerr-sonarr.service"
          ++ lib.optional (cfg.seerr.enable && cfg.radarr.enable) "seerr-radarr.service";
      })
      (lib.optionalAttrs cfg.bazarr.enable {
        arr_bazarr_api_key.restartUnits =
          lib.optional cfg.bazarr.enable "bazarr.service";
      })
      (lib.optionalAttrs (cfg.bazarr.enable || cfg.jellyfin.enable) {
        arr_opensubtitles_password.restartUnits =
          lib.optional cfg.bazarr.enable "bazarr.service"
          ++ lib.optional cfg.jellyfin.enable "jellyfin-opensubtitles-sync.service";
        arr_opensubtitles_username.restartUnits =
          lib.optional cfg.bazarr.enable "bazarr.service"
          ++ lib.optional cfg.jellyfin.enable "jellyfin-opensubtitles-sync.service";
      })
      {
        services_password.restartUnits =
          lib.optional cfg.jellyfin.enable "jellyfin.service"
          ++ lib.optional cfg.qbittorrent.enable "qbittorrent.service"
          ++ lib.optional cfg.sonarr.enable "sonarr-config.service"
          ++ lib.optional cfg.radarr.enable "radarr-config.service"
          ++ lib.optional cfg.prowlarr.enable "prowlarr-config.service";
      }
    ];
  };
}
