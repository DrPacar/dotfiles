{
  config,
  pkgs,
  lib,
  ...
}: let
  inherit (lib) mkIf optionalAttrs;
  cfg = config.server.arr;
  inherit (import ../../_lib.nix) secretRef;
  jellyfinUser = "jellyfin";
  publishedDomain =
    if cfg.domain != null
    then cfg.domain
    else config.server.domain or null;
in {
  config = mkIf (cfg.enable && cfg.jellyfin.enable) {
    assertions = [
      {
        assertion = config.sops.secrets ? services_password;
        message = "arr.jellyfin: config.sops.secrets.services_password must be defined in your secrets file.";
      }
      {
        assertion = config.sops.secrets ? arr_jellyfin_api_key;
        message = "arr.jellyfin: config.sops.secrets.arr_jellyfin_api_key must be defined in your secrets file.";
      }
    ];

    sops.secrets.services_password.restartUnits = ["jellyfin.service"];
    sops.secrets.arr_jellyfin_api_key.restartUnits = ["jellyfin.service"];

    systemd.tmpfiles.settings."10-jellyfin-transcodes" = {
      "${cfg.jellyfin.transcodingTempPath}".d = {
        mode = "0750";
        user = jellyfinUser;
        group = cfg.mediaGroup;
        age = "6h";
      };
    };

    systemd.services.jellyfin = let
      jellyfinSyncScript = pkgs.writeShellScript "jellyfin-sync-credentials" ''
        exec ${pkgs.python3}/bin/python3 ${./scripts/jellyfin-sync.py} \
          --pass-file "${config.sops.secrets.services_password.path}" \
          --key-file "${config.sops.secrets.arr_jellyfin_api_key.path}" \
          --admin-user "${cfg.jellyfin.adminUser}" \
          --media-group "${cfg.mediaGroup}"
      '';
      cleanTranscodesScript = pkgs.writeShellScript "jellyfin-clean-transcodes" ''
        if [ -d "${cfg.jellyfin.transcodingTempPath}" ]; then
          ${pkgs.findutils}/bin/find "${cfg.jellyfin.transcodingTempPath}" -mindepth 1 -delete || true
        fi
      '';
    in {
      serviceConfig = {
        UMask = "0002";
        MemoryHigh = "2500M";
        MemoryMax = "4G";
        Restart = "on-failure";
        RestartSec = "15s";
        ExecStartPre = [
          "+${cleanTranscodesScript}"
          "+${jellyfinSyncScript}"
        ];
      };
    };

    nixflix.jellyfin = {
      enable = true;
      user = jellyfinUser;
      group = cfg.mediaGroup;
      network =
        {
          internalHttpPort = cfg.jellyfin.port;
          knownProxies = [
            cfg.network.localAddress
            "::1"
          ];
          localNetworkSubnets = [
            "192.168.0.0/16"
            "10.0.0.0/8"
            "172.16.0.0/12"
            "100.64.0.0/10"
          ];
          enablePublishedServerUriByRequest = publishedDomain != null;
        }
        // optionalAttrs (publishedDomain != null) {
          publishedServerUriBySubnet = [
            "all=https://${cfg.jellyfin.subdomain}.${publishedDomain}"
          ];
        };
      openFirewall = cfg.jellyfin.openFirewall;
      apiKey = secretRef config.sops.secrets.arr_jellyfin_api_key.path;
    };
  };
}
