{
  config,
  lib,
  ...
}: let
  inherit (lib) mkIf;
  cfg = config.server.arr;
  inherit (import ../../_lib.nix) secretRef;

  prowlarrUser = "prowlarr";
  allowedHosts = lib.concatStringsSep "," cfg.network.allowedHosts;
in {
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
