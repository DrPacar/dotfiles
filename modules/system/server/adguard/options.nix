{
  config,
  lib,
  ...
}: let
  inherit (lib) mkEnableOption mkOption types;
  cfg = config.server;
in {
  options.server.adguard = {
    enable = mkOption {
      type = types.bool;
      default = false;
      description = "Enable AdGuard Home network-wide ad blocker and encrypted DNS resolver.";
    };

    port = mkOption {
      type = types.port;
      default = 3000;
      description = "Internal HTTP port for AdGuard Home web dashboard.";
    };

    subdomain = mkOption {
      type = types.str;
      default = "adguard";
      description = "Subdomain for AdGuard Home (e.g. adguard.lukpac.dev).";
    };

    lanIp = mkOption {
      type = types.nullOr types.str;
      default = null;
      example = "192.168.0.2";
      description = "Server LAN IP for local network split-horizon DNS rewrites (*.domain -> lanIp). Set to null to disable.";
    };

    tailscaleIp = mkOption {
      type = types.nullOr types.str;
      default = null;
      example = "100.64.0.1";
      description = "Server Tailscale IP for VPN client split-horizon DNS rewrites (*.domain -> tailscaleIp). Set to null to disable.";
    };

    lanSubnet = mkOption {
      type = types.str;
      default = "192.168.0.0/24";
      description = "CIDR subnet for local LAN clients.";
    };

    tailscaleSubnet = mkOption {
      type = types.str;
      default = "100.64.0.0/10";
      description = "CIDR subnet for Tailscale clients.";
    };

    routerIp = mkOption {
      type = types.str;
      default = "192.168.0.1";
      description = "LAN Gateway (Router) IP for reverse DNS (PTR) client hostname resolution.";
    };

    adminUser = mkOption {
      type = types.str;
      default = cfg.adminUser or "luka";
      description = "Admin username for AdGuard Home web dashboard authentication.";
    };

    passwordSecret = mkOption {
      type = types.path;
      default = config.sops.secrets.services_password.path;
      description = "Path to SOPS secret file containing the admin password.";
    };

    upstreamMode = mkOption {
      type = types.enum ["parallel" "load_balance" "fastest_addr"];
      default = "parallel";
      description = "Upstream DNS query mode. 'parallel' queries all upstream resolvers simultaneously for lowest response latency.";
    };

    upstreamDns = mkOption {
      type = types.listOf types.str;
      default = [
        "https://dns.quad9.net/dns-query"
        "https://cloudflare-dns.com/dns-query"
        "https://dns.mullvad.net/dns-query"
      ];
      description = ''
        Non-filtering encrypted DoH upstream resolvers. Using clean resolvers avoids
        inconsistent filtering races in parallel mode so local AdGuard blocklists stay authoritative.
      '';
    };

    fallbackDns = mkOption {
      type = types.listOf types.str;
      default = [
        "https://1.1.1.1/dns-query"
        "https://9.9.9.9/dns-query"
      ];
      description = "Fallback IP-based DoH resolvers used when primary or bootstrap DNS servers are unreachable.";
    };

    bypassSystemVpn = mkOption {
      type = types.bool;
      default = false;
      description = ''
        When true and networking.systemVPN is active, run adguardhome inside the
        vpn-bypass group so DoH upstream queries go directly out the physical WAN
        interface instead of wg-system (keeps LAN DNS online during systemVPN restarts).
        When false (default), upstream DoH traffic is additionally hidden inside wg-system.
      '';
    };

    ratelimit = mkOption {
      type = types.ints.unsigned;
      default = 300;
      description = "DDoS rate limit for DNS queries per second per client (0 to disable, 300 recommended for high-concurrency home networks).";
    };

    querylogInterval = mkOption {
      type = types.str;
      default = "30d";
      description = "Retention window for AdGuard Home's persistent query log.";
    };

    rewrites = mkOption {
      type = types.listOf (types.submodule {
        options = {
          domain = mkOption {
            type = types.str;
            example = "nas.lan";
            description = "Hostname or domain to rewrite in AdGuard Home.";
          };

          answer = mkOption {
            type = types.nullOr types.str;
            default = null;
            example = "192.168.0.10";
            description = "Uniform DNS answer (IP or CNAME) returned to all clients when split answers are not used.";
          };

          lanAnswer = mkOption {
            type = types.nullOr types.str;
            default = null;
            example = "192.168.0.2";
            description = "Split-horizon answer returned to LAN clients (lanSubnet) and localhost.";
          };

          tailscaleAnswer = mkOption {
            type = types.nullOr types.str;
            default = null;
            example = "100.64.0.1";
            description = "Split-horizon answer returned to Tailscale clients (tailscaleSubnet and Tailscale IPv6 ULA).";
          };

          includeSubdomains = mkOption {
            type = types.bool;
            default = true;
            description = "Match subdomains in addition to the exact domain name (e.g. '*.domain').";
          };
        };
      });
      default = [];
      description = "Declarative custom DNS rewrites supporting both uniform answers and LAN/Tailscale split-horizon answers.";
    };

    cli = {
      enable = mkEnableOption "the 'adguard' diagnostic and self-test CLI" // {default = true;};
    };

    watchdog = {
      enable = mkEnableOption "automated watchdog monitoring AdGuard Home WebUI and live DNS resolution" // {default = true;};

      interval = mkOption {
        type = types.str;
        default = "2m";
        description = "Interval between watchdog checks (systemd timer syntax).";
      };

      failureThreshold = mkOption {
        type = types.ints.positive;
        default = 3;
        description = "Consecutive WebUI or DNS probe failures before restarting adguardhome.service.";
      };

      testDomain = mkOption {
        type = types.str;
        default = "cloudflare.com";
        description = "Public domain resolved via 127.0.0.1:53 by watchdog and 'adguard check'.";
      };
    };

    notifications = {
      enable = mkOption {
        type = types.bool;
        default = config.server.notify.enable or false;
        description = "Enable alerts when AdGuard Home fails, recovers, or loses DNS resolution.";
      };

      handler = mkOption {
        type = types.nullOr (types.either types.str types.package);
        default = null;
        example = lib.literalExpression ''
          '''
            # $1 contains the alert message string, $2 an optional tag
            ntfy-send media "$1" "AdGuard Alert" "$2"
          '''
        '';
        description = ''
          Custom notification handler invoked on AdGuard Home watchdog events.
          Receives the alert message as $1 and an optional severity/ntfy tag as $2.
          Defaults to server.notify (ntfy) when null and server.notify.enable is true.
        '';
      };
    };
  };
}
