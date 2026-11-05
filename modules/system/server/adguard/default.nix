{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (lib) mkIf mkOption types;
  cfg = config.server;
  arrCfg = config.server.arr or {};
  arrDomain =
    if (arrCfg.enable or false)
    then (arrCfg.domain or null)
    else null;

  pythonWithBcrypt = pkgs.python3.withPackages (ps: [
    ps.bcrypt
    ps.pyyaml
  ]);
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
      example = "192.168.0.214";
      description = "Local LAN IP of the server for split-horizon DNS rewrites (*.domain -> lanIp). Set to null to disable.";
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

    ratelimit = mkOption {
      type = types.int;
      default = 300;
      description = "DDoS rate limit for DNS queries per second per client (0 to disable, 300 recommended for high-concurrency home networks).";
    };
  };

  config = mkIf (cfg.enable && cfg.adguard.enable) {
    # Ensure SOPS secret is available
    assertions = [
      {
        assertion = config.sops.secrets ? services_password;
        message = "server.adguard: config.sops.secrets.services_password must be defined in your secrets file.";
      }
    ];

    sops.secrets.services_password = {
      restartUnits = ["adguardhome-admin-sync.service" "adguardhome.service"];
    };

    # Open DNS port 53 (TCP & UDP) for the local network
    networking.firewall.allowedTCPPorts = [53];
    networking.firewall.allowedUDPPorts = [53];

    # Disable systemd-resolved DNSStubListener on 127.0.0.53:53 so AdGuard can bind 0.0.0.0:53
    services.resolved.settings = {
      Resolve = {
        DNSStubListener = "no";
      };
    };

    # Ensure admin user is injected from SOPS secret before AdGuard Home starts
    systemd.services.adguardhome-admin-sync = {
      description = "Synchronize AdGuard Home admin credentials from SOPS";
      after = ["sops-nix.service"];
      before = ["adguardhome.service"];
      requiredBy = ["adguardhome.service"];
      wantedBy = ["multi-user.target"];

      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = "${pythonWithBcrypt}/bin/python3 ${./scripts/sync-admin.py} --config /var/lib/AdGuardHome/AdGuardHome.yaml --secret ${cfg.adguard.passwordSecret} --username ${cfg.adguard.adminUser}";
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
          upstream_mode = cfg.adguard.upstreamMode;
          fastest_addr = true;
          cache_size = 67108864; # 64 MB DNS Cache
          cache_ttl_min = 300; # 5 min minimum TTL
          cache_optimistic = true;
          edns_client_subnet.enabled = false;
          enable_dnssec = true;
          refuse_any = true;
          ratelimit = cfg.adguard.ratelimit;
          use_private_ptr_resolvers = true;
          local_ptr_upstreams = [cfg.adguard.routerIp];
          trusted_proxies = [
            "127.0.0.0/8"
            "::1/128"
          ];
        };
        filtering = mkIf (cfg.adguard.lanIp != null && cfg.domain != null) {
          protection_enabled = true;
          filtering_enabled = true;
          rewrites_enabled = true;
          rewrites =
            [
              {
                domain = "*.${cfg.domain}";
                answer = cfg.adguard.lanIp;
                enabled = true;
              }
              {
                domain = cfg.domain;
                answer = cfg.adguard.lanIp;
                enabled = true;
              }
            ]
            ++ lib.optionals (arrDomain != null && arrDomain != cfg.domain) [
              {
                domain = "*.${arrDomain}";
                answer = cfg.adguard.lanIp;
                enabled = true;
              }
              {
                domain = arrDomain;
                answer = cfg.adguard.lanIp;
                enabled = true;
              }
            ];
        };
        filters = [
          {
            enabled = true;
            name = "AdGuard DNS filter";
            url = "https://adguardteam.github.io/HostlistsRegistry/assets/filter_1.txt";
            id = 1;
          }
          {
            enabled = true;
            name = "HaGeZi Multi PRO";
            url = "https://raw.githubusercontent.com/hagezi/dns-blocklists/main/adblock/pro.txt";
            id = 2;
          }
          {
            enabled = true;
            name = "HaGeZi Threat Intelligence Feeds (TIF)";
            url = "https://raw.githubusercontent.com/hagezi/dns-blocklists/main/adblock/tif.txt";
            id = 3;
          }
          {
            enabled = true;
            name = "OISD Big";
            url = "https://big.oisd.nl";
            id = 4;
          }
        ];
      };
    };
  };
}
