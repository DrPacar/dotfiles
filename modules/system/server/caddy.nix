{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (lib) mkIf mkMerge;
  cfg = config.server;

  hostName = config.networking.hostName;
  tailscaleFqdn =
    if cfg.tailscaleDomain != null
    then "${hostName}.${cfg.tailscaleDomain}"
    else null;

  customDomain = cfg.domain;

  portSuffix =
    if cfg.dashboard.port == 80
    then ""
    else ":${toString cfg.dashboard.port}";

  mkHttpHost = host: "http://${host}${portSuffix}";

  servicesList = import ./dashboard/_services.nix {inherit lib config;};

  dashboardWeb = import ./dashboard/_html.nix {
    inherit pkgs lib config hostName servicesList;
  };

  # Local and Tailscale domains for plaintext / HTTP reverse proxying
  plainSubdomainDomains =
    [hostName]
    ++ lib.optional (tailscaleFqdn != null) tailscaleFqdn;

  # 1. Plaintext Subdomain Virtual Hosts (e.g. adguard.lighthouse, jellyfin.lighthouse, etc.)
  mkPlainSubdomainVhost = s: let
    allSubNames = [s.subdomain] ++ (s.aliases or []);
    hostsList = lib.flatten (map (sub: map (d: mkHttpHost "${sub}.${d}") plainSubdomainDomains) allSubNames);
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

  plainSubdomainVhosts = lib.foldl' lib.mergeAttrs {} (map mkPlainSubdomainVhost servicesList);

  # 2. Main Landing Page Virtual Host for local plaintext HTTP access (localhost, 127.0.0.1, lighthouse)
  plainDashboardVhost = let
    dashboardHostsList = [(mkHttpHost "localhost") (mkHttpHost "127.0.0.1") (mkHttpHost hostName)];
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

  # 3. Tailscale HTTPS Virtual Host with automated Let's Encrypt certificates via Tailscale LocalAPI
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

  # Tailscale HTTP -> HTTPS redirect
  tailscaleHttpRedirectVhost = mkIf (tailscaleFqdn != null) {
    "http://${tailscaleFqdn}${portSuffix}" = {
      extraConfig = ''
        redir https://${tailscaleFqdn}{uri} permanent
      '';
    };
  };

  # 4. Custom Public Domain Dashboard (e.g. https://media.lukpac.dev) with Let's Encrypt Wildcard ACME Cert
  customDomainHttpsVhost = mkIf (customDomain != null) {
    "https://${customDomain}" = {
      extraConfig = ''
        tls /var/lib/acme/${customDomain}/cert.pem /var/lib/acme/${customDomain}/key.pem
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

  # Custom Domain HTTP -> HTTPS redirect (e.g. http://media.lukpac.dev -> https://media.lukpac.dev)
  customDomainHttpRedirectVhost = mkIf (customDomain != null) {
    "http://${customDomain}${portSuffix}" = {
      extraConfig = ''
        redir https://${customDomain}{uri} permanent
      '';
    };
  };

  # 5. Custom Domain Subdomains HTTPS (e.g. https://adguard.media.lukpac.dev, https://jellyfin.media.lukpac.dev) with Wildcard ACME Cert
  mkCustomDomainSubVhost = s: let
    allSubNames = [s.subdomain] ++ (s.aliases or []);
    httpsHosts = map (sub: "https://${sub}.${customDomain}") allSubNames;
    httpHosts = map (sub: "http://${sub}.${customDomain}${portSuffix}") allSubNames;
    httpsKey = lib.concatStringsSep ", " httpsHosts;
    httpKey = lib.concatStringsSep ", " httpHosts;
  in {
    "${httpsKey}" = {
      extraConfig = ''
        tls /var/lib/acme/${customDomain}/cert.pem /var/lib/acme/${customDomain}/key.pem
        reverse_proxy 127.0.0.1:${toString s.port} {
          header_up Host {host}
          header_up X-Real-IP {remote_host}
        }
      '';
    };
    "${httpKey}" = {
      extraConfig = ''
        redir https://${lib.head allSubNames}.${customDomain}{uri} permanent
      '';
    };
  };

  customDomainSubdomainVhosts = mkIf (customDomain != null) (
    lib.foldl' lib.mergeAttrs {} (map mkCustomDomainSubVhost servicesList)
  );
in {
  config = mkIf cfg.enable {
    # ACME automated wildcard certificate generation via Name.com DNS-01 API
    security.acme = mkIf (customDomain != null) {
      acceptTerms = true;
      defaults.email = "lukapacar06@gmail.com";
      certs."${customDomain}" = {
        domain = customDomain;
        extraDomainNames = ["*.${customDomain}"];
        dnsProvider = "namedotcom";
        dnsResolver = "1.1.1.1:53";
        environmentFile = config.sops.secrets.namecom_env.path;
        group = "caddy";
        reloadServices = ["caddy.service"];
      };
    };

    # Set proper permissions so acme service can read the Name.com API credentials
    sops.secrets.namecom_env = mkIf (customDomain != null) {
      owner = "acme";
      group = "acme";
      mode = "0400";
    };

    # Allow Caddy to fetch TLS certificates from Tailscale LocalAPI and read ACME certs
    services.tailscale.permitCertUid = lib.mkDefault "caddy";
    users.users.caddy.extraGroups = lib.optional (customDomain != null) "acme";

    # Ensure Caddy starts after tailscaled and acme certificate generation
    systemd.services.caddy = {
      after =
        [
          "tailscaled.service"
        ]
        ++ lib.optional (customDomain != null) "acme-${customDomain}.service";
      wants =
        (lib.optional (config.services.tailscale.enable or false) "tailscaled.service")
        ++ lib.optional (customDomain != null) "acme-${customDomain}.service";
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
        customDomainHttpsVhost
        customDomainHttpRedirectVhost
        plainSubdomainVhosts
        customDomainSubdomainVhosts
      ];
    };
  };
}
