{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (lib) mkOption mkIf types;
  cfg = config.server.arr;
  inherit (import ../_lib.nix) secretRef;

  bazarrUser = "bazarr";
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
  };

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
        assertion = !cfg.radarr.enable || config.sops.secrets ? arr_radarr_api_key;
        message = "arr.bazarr: config.sops.secrets.arr_radarr_api_key must be defined when Radarr is enabled.";
      }
      {
        assertion = !cfg.jellyfin.enable || config.sops.secrets ? arr_jellyfin_api_key;
        message = "arr.bazarr: config.sops.secrets.arr_jellyfin_api_key must be defined when Jellyfin is enabled.";
      }
    ];

    # Ensure Bazarr writes subtitle files with group-writable permissions (rw-rw-r--)
    systemd.services.bazarr.serviceConfig.UMask = "0002";

    sops.secrets.arr_jellyfin_api_key.restartUnits =
      mkIf cfg.jellyfin.enable ["bazarr.service"];

    services.bazarr = {
      enable = true;
      user = bazarrUser;
      group = cfg.mediaGroup;
      openFirewall = false;

      settings = {
        general = {
          ip = cfg.network.bindAddress;
          port = cfg.bazarr.port;
          use_sonarr = cfg.sonarr.enable;
          use_radarr = cfg.radarr.enable;
          use_jellyfin = cfg.jellyfin.enable;
          enabled_providers = [
            "animetosho"
            "embeddedsubtitles"
            "yifysubtitles"
          ];
          movie_default_enabled = true;
          movie_default_profile = 1;
          serie_default_enabled = true;
          serie_default_profile = 1;
        };
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
          series_library_ids = ["0c41907140d802bb58430fed7e2cd79e" "a656b907eb3a73532e40e44b968d0225"];
          refresh_method = "immediate";
        };
      };
    };

    # Automatically ensure default language profile (German & English) in Bazarr database
    systemd.services.bazarr-setup-profile = {
      description = "Ensure default language profiles in Bazarr database";
      before = ["bazarr.service"];
      wantedBy = ["multi-user.target"];

      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        User = bazarrUser;
        Group = cfg.mediaGroup;
        StateDirectory = "bazarr";
      };

      script = ''
        exec ${pkgs.python3}/bin/python3 ${../scripts/bazarr-setup.py}
      '';
    };
  };
}
