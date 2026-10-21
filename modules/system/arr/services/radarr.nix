{
  config,
  lib,
  ...
}: let
  inherit (lib) mkOption mkIf types;
  cfg = config.arr;
  inherit (import ../_lib.nix) secretRef;

  radarrUser = "radarr";
  allowedHosts = lib.concatStringsSep "," cfg.network.allowedHosts;
in {
  options.arr.radarr = {
    enable = mkOption {
      type = types.bool;
      default = true;
      description = "Enable Radarr movie manager.";
    };

    port = mkOption {
      type = types.port;
      default = 7878;
      description = "Port for Radarr web interface.";
    };
  };

  config = mkIf (cfg.enable && cfg.radarr.enable) {
    assertions = [
      {
        assertion = config.sops.secrets ? arr_radarr_api_key;
        message = "arr.radarr: config.sops.secrets.arr_radarr_api_key must be defined in your secrets file.";
      }
      {
        assertion = cfg.adminPasswordFile != null;
        message = "arr.radarr: arr.adminPasswordFile must be set to configure Radarr web authentication.";
      }
    ];

    nixflix.radarr = {
      enable = true;
      user = radarrUser;
      group = cfg.mediaGroup;
      openFirewall = false;
      mediaDirs = [cfg.paths.movies];

      settings = {
        server.bindaddress = cfg.network.bindAddress;
        server.allowedhosts = allowedHosts;
      };

      config = {
        hostConfig = {
          bindAddress = cfg.network.bindAddress;
          port = cfg.radarr.port;
          authenticationMethod = "forms";
          authenticationRequired = "disabledForLocalAddresses";
          username = cfg.adminUser;
          password = secretRef cfg.adminPasswordFile;
        };
        apiKey = secretRef config.sops.secrets.arr_radarr_api_key.path;
      };
    };
  };
}
