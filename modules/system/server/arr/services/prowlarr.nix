{
  config,
  lib,
  ...
}: let
  inherit (lib) mkOption mkIf types;
  cfg = config.server.arr;
  inherit (import ../_lib.nix) secretRef;

  prowlarrUser = "prowlarr";
  allowedHosts = lib.concatStringsSep "," cfg.network.allowedHosts;
in {
  options.server.arr.prowlarr = {
    enable = mkOption {
      type = types.bool;
      default = true;
      description = "Enable Prowlarr indexer manager and proxy synchronizer.";
    };

    port = mkOption {
      type = types.port;
      default = 9696;
      description = "Port for Prowlarr web interface.";
    };

    subdomain = mkOption {
      type = types.str;
      default = "prowlarr";
      description = "Subdomain name for Prowlarr reverse proxy routing.";
    };

    indexers = mkOption {
      type = types.listOf types.attrs;
      default = [];
      example = [
        {name = "Nyaa.si";}
        {name = "YTS";}
        {name = "The Pirate Bay";}
      ];
      description = "Declarative list of Prowlarr indexers managed by Nixflix. Note: Any indexer not listed here will be removed on rebuild.";
    };
  };

  config = mkIf (cfg.enable && cfg.prowlarr.enable) {
    assertions = [
      {
        assertion = config.sops.secrets ? arr_prowlarr_api_key;
        message = "arr.prowlarr: config.sops.secrets.arr_prowlarr_api_key must be defined in your secrets file.";
      }
      {
        assertion = cfg.adminPasswordFile != null;
        message = "arr.prowlarr: arr.adminPasswordFile must be set to configure Prowlarr web authentication.";
      }
    ];

    nixflix.prowlarr = {
      enable = true;
      user = prowlarrUser;
      group = cfg.mediaGroup;
      openFirewall = false;

      settings = {
        server.bindaddress = cfg.network.bindAddress;
        server.allowedhosts = allowedHosts;
      };

      config = {
        hostConfig = {
          bindAddress = cfg.network.bindAddress;
          port = cfg.prowlarr.port;
          authenticationMethod = "forms";
          authenticationRequired = "disabledForLocalAddresses";
          username = cfg.adminUser;
          password = secretRef cfg.adminPasswordFile;
        };
        apiKey = secretRef config.sops.secrets.arr_prowlarr_api_key.path;
        indexers = cfg.prowlarr.indexers;
      };
    };
  };
}
