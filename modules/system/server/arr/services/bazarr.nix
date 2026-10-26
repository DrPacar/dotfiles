{
  config,
  lib,
  ...
}: let
  inherit (lib) mkOption mkIf types;
  cfg = config.arr;
  inherit (import ../_lib.nix) secretRef;

  bazarrUser = "bazarr";
in {
  options.arr.bazarr = {
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
    ];

    # Ensure Bazarr writes subtitle files with group-writable permissions (rw-rw-r--)
    systemd.services.bazarr.serviceConfig.UMask = "0002";

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
      };
    };
  };
}
