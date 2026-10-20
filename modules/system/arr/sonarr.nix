{
  config,
  lib,
  ...
}: let
  inherit (lib) mkOption mkIf types;
  cfg = config.arr;
  inherit (import ./_lib.nix) secretRef bindAddress mkAllowedHosts;

  allowedHosts = mkAllowedHosts config.networking.hostName cfg.tailscaleDomain;

  mkSonarrInstance = {
    user,
    mediaSubdir,
    port,
    apiKeySecret,
  }: {
    enable = true;
    inherit user;
    group = cfg.mediaGroup;
    openFirewall = false;
    mediaDirs = ["${cfg.dataDir}/media/${mediaSubdir}"];

    settings = {
      server.bindaddress = bindAddress;
      server.allowedhosts = allowedHosts;
    };

    config = {
      hostConfig = {
        inherit bindAddress port;
        authenticationMethod = "forms";
        authenticationRequired = "disabledForLocalAddresses";
        username = config.user.primary;
        password = secretRef config.sops.secrets.arr_jellyfin_admin_password.path;
      };
      apiKey = secretRef apiKeySecret.path;
    };
  };
in {
  options.arr.sonarr = {
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
    };
  };

  config = mkIf (cfg.enable && cfg.sonarr.enable) {
    nixflix = {
      # Standard Sonarr instance
      sonarr = mkSonarrInstance {
        user = "sonarr";
        mediaSubdir = "tv";
        port = cfg.sonarr.port;
        apiKeySecret = config.sops.secrets.arr_sonarr_api_key;
      };

      # Sonarr Anime instance
      sonarr-anime = mkIf cfg.sonarr.anime.enable (mkSonarrInstance {
        user = "sonarr-anime";
        mediaSubdir = "anime";
        port = cfg.sonarr.anime.port;
        apiKeySecret = config.sops.secrets.arr_sonarr_anime_api_key;
      });
    };
  };
}
