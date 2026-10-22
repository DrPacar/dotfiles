{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (lib) mkIf mkMerge;
  cfg = config.arr;

  hostName = config.networking.hostName;
  tailscaleFqdn =
    if cfg.tailscaleDomain != null
    then "${hostName}.${cfg.tailscaleDomain}"
    else null;

  # Local plaintext hostnames (excluding Tailscale FQDN which gets HTTPS)
  localDomains =
    [hostName]
    ++ lib.optional (cfg.domain != null) cfg.domain;

  # Base domains across which Caddy will route subdomain requests
  allSubdomainDomains =
    localDomains
    ++ lib.optional (tailscaleFqdn != null) tailscaleFqdn;

  portSuffix =
    if cfg.dashboard.port == 80
    then ""
    else ":${toString cfg.dashboard.port}";

  mkHttpHost = host: "http://${host}${portSuffix}";

  servicesList = import ./_services.nix {inherit lib cfg;};

  dashboardWeb = import ./_html.nix {
    inherit pkgs lib cfg hostName servicesList;
  };

  # Helper to generate virtual host definitions for Caddy subdomains
  mkSubdomainVhost = s: let
    allSubNames = [s.subdomain] ++ (s.aliases or []);
    hostsList = lib.flatten (map (sub: map (d: mkHttpHost "${sub}.${d}") allSubdomainDomains) allSubNames);
    vhostKey = lib.concatStringsSep ", " hostsList;
  in {
    "${vhostKey}" = {
      extraConfig = ''
        reverse_proxy 127.0.0.1:${toString s.port} {
          header_up Host {host}
          header_up X-Real-IP {remote_host}
        }
      '';
    };
  };

  # Flatten all subdomain vhosts
  allSubdomainVhosts = lib.foldl' lib.mergeAttrs {} (map mkSubdomainVhost servicesList);

  # Main Landing Page Virtual Host for local plaintext HTTP access
  plainDashboardVhost = let
    dashboardHostsList = [(mkHttpHost "localhost") (mkHttpHost "127.0.0.1")] ++ (map mkHttpHost localDomains);
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

  # Tailscale HTTPS Virtual Host with automated Let's Encrypt certificates via Tailscale LocalAPI
  tailscaleHttpsVhost = mkIf (tailscaleFqdn != null) {
    "https://${tailscaleFqdn}" = {
      extraConfig = ''
        tls {
          get_certificate tailscale
        }
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

  # Redirect HTTP requests on the Tailscale domain to HTTPS
  tailscaleHttpRedirectVhost = mkIf (tailscaleFqdn != null) {
    "http://${tailscaleFqdn}${portSuffix}" = {
      extraConfig = ''
        redir https://${tailscaleFqdn}{uri} permanent
      '';
    };
  };
in {
  config = mkIf (cfg.enable && cfg.dashboard.enable) {
    # Ensure Caddy starts after tailscaled so the LocalAPI socket is ready
    systemd.services.caddy = {
      after = ["tailscaled.service"];
      wants = lib.optional (config.services.tailscale.enable or false) "tailscaled.service";
    };

    # Caddy Reverse Proxy
    services.caddy = {
      enable = true;
      globalConfig = ''
        auto_https off
      '';
      virtualHosts = mkMerge [
        plainDashboardVhost
        tailscaleHttpsVhost
        tailscaleHttpRedirectVhost
        allSubdomainVhosts
      ];
    };
  };
}
