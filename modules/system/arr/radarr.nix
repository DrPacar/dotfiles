{
  config,
  lib,
  ...
}: let
  inherit (lib) mkOption mkIf types;
  cfg = config.arr;
  inherit (import ./_lib.nix) secretRef bindAddress mkAllowedHosts;

  radarrUser = "radarr";
  allowedHosts = mkAllowedHosts config.networking.hostName cfg.tailscaleDomain;
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
    nixflix.radarr = {
      enable = true;
      user = radarrUser;
      group = cfg.mediaGroup;
      openFirewall = false;
      mediaDirs = ["${cfg.dataDir}/media/movies"];

      settings = {
        server.bindaddress = bindAddress;
        server.allowedhosts = allowedHosts;
      };

      config = {
        hostConfig = {
          inherit bindAddress;
          port = cfg.radarr.port;
          authenticationMethod = "forms";
          authenticationRequired = "disabledForLocalAddresses";
          username = config.user.primary;
          password = secretRef config.sops.secrets.arr_jellyfin_admin_password.path;
        };
        apiKey = secretRef config.sops.secrets.arr_radarr_api_key.path;
      };
    };
  };
}
