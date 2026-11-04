{
  config,
  pkgs,
  lib,
  ...
}: let
  inherit (lib) mkIf;
  cfg = config.server.arr;
  inherit (import ../../_lib.nix) secretRef;
  jellyfinUser = "jellyfin";
in {
  imports = [
    ./options.nix
    ./hardware.nix
    ./encoding.nix
    ./libraries.nix
    ./users.nix
    ./plugins.nix
    ./branding.nix
    ./system.nix
  ];

  config = mkIf (cfg.enable && cfg.jellyfin.enable) {
    assertions = [
      {
        assertion = config.sops.secrets ? arr_jellyfin_admin_password;
        message = "arr.jellyfin: config.sops.secrets.arr_jellyfin_admin_password must be defined in your secrets file.";
      }
      {
        assertion = config.sops.secrets ? arr_jellyfin_api_key;
        message = "arr.jellyfin: config.sops.secrets.arr_jellyfin_api_key must be defined in your secrets file.";
      }
    ];

    sops.secrets.arr_jellyfin_admin_password.restartUnits = ["jellyfin.service"];
    sops.secrets.arr_jellyfin_api_key.restartUnits = ["jellyfin.service"];

    # Synchronize admin credentials and API key directly into the SQLite database before startup
    systemd.services.jellyfin = let
      jellyfinSyncScript = pkgs.writeShellScript "jellyfin-sync-credentials" ''
        exec ${pkgs.python3}/bin/python3 ${./scripts/jellyfin-sync.py} \
          --pass-file "${config.sops.secrets.arr_jellyfin_admin_password.path}" \
          --key-file "${config.sops.secrets.arr_jellyfin_api_key.path}" \
          --admin-user "${cfg.jellyfin.adminUser}" \
          --media-group "${cfg.mediaGroup}"
      '';
    in {
      serviceConfig = {
        UMask = "0002";
        ExecStartPre = [
          "+${jellyfinSyncScript}"
        ];
      };
    };

    # Core Nixflix Jellyfin integration
    nixflix.jellyfin = {
      enable = true;
      user = jellyfinUser;
      group = cfg.mediaGroup;
      network.internalHttpPort = cfg.jellyfin.port;
      openFirewall = true;
      apiKey = secretRef config.sops.secrets.arr_jellyfin_api_key.path;
    };
  };
}
