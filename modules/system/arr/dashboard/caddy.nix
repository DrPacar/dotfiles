{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (lib) mkIf;
  cfg = config.arr;

  hostName = config.networking.hostName;
  tailscaleFqdn =
    if cfg.tailscaleDomain != null
    then "${hostName}.${cfg.tailscaleDomain}"
    else null;

  # Base domains across which Caddy will route requests
  baseDomains =
    [hostName]
    ++ lib.optional (tailscaleFqdn != null) tailscaleFqdn
    ++ lib.optional (cfg.domain != null) cfg.domain;

  portSuffix =
    if cfg.dashboard.port == 80
    then ""
    else ":${toString cfg.dashboard.port}";

  mkHttpHost = host: "http://${host}${portSuffix}";

  servicesList = import ./_services.nix {inherit lib cfg;};

  dashboardWeb = import ./_html.nix {
    inherit pkgs lib cfg hostName servicesList;
  };

  # Helper to generate virtual host definitions for Caddy
  mkSubdomainVhost = s: let
    allSubNames = [s.subdomain] ++ (s.aliases or []);
    hostsList = lib.flatten (map (sub: map (d: mkHttpHost "${sub}.${d}") baseDomains) allSubNames);
    vhostKey = lib.concatStringsSep ", " hostsList;
  in {
    "${vhostKey}" = {
      extraConfig = ''
        reverse_proxy 127.0.0.1:${toString s.port} {
          header_up Host {host}
          header_up X-Real-IP {remote_host}
          header_up X-Forwarded-For {remote_host}
          header_up X-Forwarded-Proto {scheme}
        }
      '';
    };
  };

  # Flatten all subdomain vhosts
  allSubdomainVhosts = lib.foldl' lib.mergeAttrs {} (map mkSubdomainVhost servicesList);

  # Main Landing Page Virtual Host with API reverse proxy
  mainDashboardVhost = let
    dashboardHostsList = [(mkHttpHost "localhost") (mkHttpHost "127.0.0.1")] ++ (map mkHttpHost baseDomains);
    vhostKey = lib.concatStringsSep ", " dashboardHostsList;
  in {
    "${vhostKey}" = {
      extraConfig = ''
        handle /api/* {
          reverse_proxy 127.0.0.1:9095
        }
        handle {
          root * ${dashboardWeb}
          file_server
        }
      '';
    };
  };
in {
  config = mkIf (cfg.enable && cfg.dashboard.enable) {
    # Caddy Reverse Proxy
    services.caddy = {
      enable = true;
      globalConfig = ''
        auto_https off
      '';
      virtualHosts = lib.mkMerge [
        mainDashboardVhost
        allSubdomainVhosts
      ];
    };
  };
}
