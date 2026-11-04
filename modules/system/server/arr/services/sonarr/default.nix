{
  config,
  lib,
  ...
}: let
  inherit (lib) mkIf;
  cfg = config.server.arr;
  inherit (import ../../_lib.nix) secretRef;

  allowedHosts = lib.concatStringsSep "," cfg.network.allowedHosts;

  mkSonarrInstance = {
    user,
    mediaDirs,
    port,
    apiKeySecret,
  }: {
    enable = true;
    inherit user;
    group = cfg.mediaGroup;
    openFirewall = false;
    inherit mediaDirs;

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
      sonarr = mkSonarrInstance {
        user = "sonarr";
        mediaDirs =
          [cfg.paths.tv]
          ++ lib.optional (!cfg.sonarr.anime.enable) cfg.paths.anime;
        port = cfg.sonarr.port;
        apiKeySecret = config.sops.secrets.arr_sonarr_api_key;
      };

      sonarr-anime = mkIf cfg.sonarr.anime.enable (mkSonarrInstance {
        user = "sonarr-anime";
        mediaDirs = [cfg.paths.anime];
        port = cfg.sonarr.anime.port;
        apiKeySecret = config.sops.secrets.arr_sonarr_anime_api_key;
      });
    };
  };
}
