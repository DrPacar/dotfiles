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
      default = true;
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
          ];
          bootstrap_dns = [
            "9.9.9.9"
            "1.1.1.1"
          ];
        };
      };
    };
  };
}
