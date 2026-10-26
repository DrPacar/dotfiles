{
  config,
  lib,
  ...
}: let
  inherit (lib) mkOption mkIf types;
  cfg = config.server.arr;
  inherit (import ../_lib.nix) secretRef;

  allowedHosts = lib.concatStringsSep "," cfg.network.allowedHosts;

  mkSonarrInstance = {
    user,
    mediaDir,
    port,
    apiKeySecret,
  }: {
    enable = true;
    inherit user;
    group = cfg.mediaGroup;
    openFirewall = false;
    mediaDirs = [mediaDir];

    settings = {
      server.bindaddress = cfg.network.bindAddress;
      server.allowedhosts = allowedHosts;
    };

    config = {
      hostConfig = {
        bindAddress = cfg.network.bindAddress;
        inherit port;
        authenticationMethod = "forms";
        authenticationRequired = "disabledForLocalAddresses";
        username = cfg.adminUser;
        password = secretRef cfg.adminPasswordFile;
      };
      apiKey = secretRef apiKeySecret.path;
    };
  };
in {
  options.server.arr.sonarr = {
    enable = mkOption {
      type = types.bool;
      default = true;
      description = "Enable Sonarr TV series manager.";
    };

    port = mkOption {
      type = types.port;
      default = 8989;
      description = "Port for Sonarr web interface.";
    };

    subdomain = mkOption {
      type = types.str;
      default = "sonarr";
      description = "Subdomain name for Sonarr reverse proxy routing.";
    };

    anime = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = "Enable separate Sonarr Anime instance for dedicated anime management.";
      };

      port = mkOption {
        type = types.port;
        default = 8990;
        description = "Port for Sonarr Anime web interface.";
      };

      subdomain = mkOption {
        type = types.str;
        default = "anime";
        description = "Subdomain name for Sonarr Anime reverse proxy routing.";
      };
    };
  };

  config = mkIf (cfg.enable && cfg.sonarr.enable) {
    assertions = [
      {
        assertion = config.sops.secrets ? arr_sonarr_api_key;
        message = "arr.sonarr: config.sops.secrets.arr_sonarr_api_key must be defined in your secrets file.";
      }
      {
        assertion = !cfg.sonarr.anime.enable || config.sops.secrets ? arr_sonarr_anime_api_key;
        message = "arr.sonarr.anime: config.sops.secrets.arr_sonarr_anime_api_key must be defined in your secrets file when Sonarr Anime is enabled.";
      }
      {
        assertion = cfg.adminPasswordFile != null;
        message = "arr.sonarr: arr.adminPasswordFile must be set to configure Sonarr web authentication.";
      }
    ];

    nixflix = {
      # Standard Sonarr instance
      sonarr = mkSonarrInstance {
        user = "sonarr";
        mediaDir = cfg.paths.tv;
        port = cfg.sonarr.port;
        apiKeySecret = config.sops.secrets.arr_sonarr_api_key;
      };

      # Sonarr Anime instance
      sonarr-anime = mkIf cfg.sonarr.anime.enable (mkSonarrInstance {
        user = "sonarr-anime";
        mediaDir = cfg.paths.anime;
        port = cfg.sonarr.anime.port;
        apiKeySecret = config.sops.secrets.arr_sonarr_anime_api_key;
      });
    };
  };
}
