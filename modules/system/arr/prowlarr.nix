{
  config,
  lib,
  ...
}: let
  inherit (lib) mkOption mkIf types;
  cfg = config.arr;
  inherit (import ./_lib.nix) secretRef bindAddress mkAllowedHosts;

  prowlarrUser = "prowlarr";
  allowedHosts = mkAllowedHosts config.networking.hostName cfg.tailscaleDomain;
in {
  options.arr.prowlarr = {
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

    indexers = mkOption {
      type = types.listOf types.attrs;
      default = [];
      description = "Declarative list of Prowlarr indexers.";
    };
  };

  config = mkIf (cfg.enable && cfg.prowlarr.enable) {
    assertions = [
      {
        assertion = config.sops.secrets ? arr_prowlarr_api_key;
        message = "arr.prowlarr: config.sops.secrets.arr_prowlarr_api_key must be defined in your secrets file.";
      }
    ];

    nixflix.prowlarr = {
      enable = true;
      user = prowlarrUser;
      group = cfg.mediaGroup;
      openFirewall = false;

      settings = {
        server.bindaddress = bindAddress;
        server.allowedhosts = allowedHosts;
      };

      config = {
        hostConfig = {
          inherit bindAddress;
          port = cfg.prowlarr.port;
          authenticationMethod = "forms";
          authenticationRequired = "disabledForLocalAddresses";
          username = config.user.primary;
          password = secretRef config.sops.secrets.arr_jellyfin_admin_password.path;
        };
        apiKey = secretRef config.sops.secrets.arr_prowlarr_api_key.path;
        indexers = cfg.prowlarr.indexers;
      };
    };
  };
}
