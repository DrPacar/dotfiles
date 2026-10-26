{
  config,
  lib,
  ...
}: let
  inherit (lib) mkIf mkOption types;
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
      description = "Subdomain for AdGuard Home (e.g. adguard.media.lukpac.dev).";
    };

    lanIp = mkOption {
      type = types.nullOr types.str;
      default = "192.168.0.73";
      description = "Local LAN IP of the server for split-brain DNS rewrites (*.domain -> lanIp). Set to null to disable.";
    };
  };

  config = mkIf (cfg.enable && cfg.adguard.enable) {
    # Open DNS port 53 (TCP & UDP) for the local network
    networking.firewall.allowedTCPPorts = [53];
    networking.firewall.allowedUDPPorts = [53];

    # Disable systemd-resolved DNSStubListener on 127.0.0.53:53 so AdGuard can bind 0.0.0.0:53
    services.resolved.settings = {
      Resolve = {
        DNSStubListener = "no";
      };
    };

    # AdGuard Home native NixOS service
    services.adguardhome = {
      enable = true;
      mutableSettings = true;
      settings = {
        http.address = "127.0.0.1:${toString cfg.adguard.port}";
        dns = {
          bind_hosts = ["0.0.0.0"];
          port = 53;
          upstream_dns = [
            "https://dns.quad9.net/dns-query"
            "https://cloudflare-dns.com/dns-query"
            "https://adblock.doh.mullvad.net/dns-query"
          ];
          bootstrap_dns = [
            "9.9.9.9"
            "1.1.1.1"
            "149.112.112.112"
          ];
          fastest_addr = true;
          cache_size = 67108864;
          cache_ttl_min = 300;
          cache_optimistic = true;
          edns_client_subnet.enabled = false;
          dnssec = true;
        };
        filtering = mkIf (cfg.adguard.lanIp != null && cfg.domain != null) {
          rewrites = [
            {
              domain = "*.${cfg.domain}";
              answer = cfg.adguard.lanIp;
            }
            {
              domain = cfg.domain;
              answer = cfg.adguard.lanIp;
            }
          ];
        };
        filters = [
          {
            enabled = true;
            url = "https://adguardteam.github.io/HostlistsRegistry/assets/filter_1.txt";
            name = "AdGuard DNS filter";
            id = 1;
          }
          {
            enabled = true;
            url = "https://raw.githubusercontent.com/hagezi/dns-blocklists/main/adblock/pro.txt";
            name = "HaGeZi Multi PRO";
            id = 2;
          }
        ];
      };
    };
  };
}
