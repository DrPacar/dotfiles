{
  config,
  lib,
  ...
}: let
  inherit (lib) mkIf mkOption types;
  cfg = config.server;

  hostName = config.networking.hostName;
  tailscaleFqdn =
    if cfg.tailscaleDomain != null
    then "${hostName}.${cfg.tailscaleDomain}"
    else null;

  # Only local hostnames should be mapped to 127.0.0.1 in /etc/hosts
  # Public registered domains (like lukpac.dev) must resolve via real DNS so ACME/Lego can query NS records
  localBaseDomains =
    [hostName]
    ++ lib.optional (tailscaleFqdn != null) tailscaleFqdn;

  servicesList = import ./_services.nix {inherit lib config;};

  allSubdomainNames = lib.unique (
    lib.flatten (
      map (
        s: let
          allSubNames = [s.subdomain] ++ (s.aliases or []);
        in
          map (sub: map (d: "${sub}.${d}") localBaseDomains) allSubNames
      )
      servicesList
    )
  );
in {
  options.server.dashboard = {
    enable = mkOption {
      type = types.bool;
      default = true;
      description = "Enable centralized landing page dashboard.";
    };

    port = mkOption {
      type = types.port;
      default = 80;
      description = "HTTP port on which Caddy listens for the dashboard.";
    };

    addHostsEntries = mkOption {
      type = types.bool;
      default = true;
      description = "Whether to automatically add /etc/hosts entries mapping all subdomains to 127.0.0.1.";
    };
  };

  config = mkIf (cfg.enable && cfg.dashboard.enable) {
    # Open dashboard HTTP and HTTPS ports in firewall
    networking.firewall.allowedTCPPorts = [
      cfg.dashboard.port
      443
    ];

    # Map all subdomains to localhost in /etc/hosts for instant local resolution
    networking.hosts."127.0.0.1" = mkIf cfg.dashboard.addHostsEntries allSubdomainNames;
  };
}
