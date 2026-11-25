{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (lib) mkDefault mkIf optional optionals;
  cfg = config.server;
  adg = import ./_lib.nix {inherit config lib pkgs;};

  mkRulePrefix = includeSubdomains: domain:
    if includeSubdomains
    then "||${domain}^"
    else "|${domain}^";

  # Shared helper producing AdGuard filtering/user_rules entries for a rewrite record
  mkSplitUserRules = {
    domain,
    lanAnswer ? null,
    tailscaleAnswer ? null,
    includeSubdomains ? true,
  }: let
    prefix = mkRulePrefix includeSubdomains domain;
  in
    optionals (tailscaleAnswer != null) [
      "${prefix}$dnsrewrite=NOERROR;A;${tailscaleAnswer},client=${cfg.adguard.tailscaleSubnet}|fd7a:115c:a1e0::/48"
    ]
    ++ optionals (lanAnswer != null) [
      "${prefix}$dnsrewrite=NOERROR;A;${lanAnswer},client=${cfg.adguard.lanSubnet}"
      "${prefix}$dnsrewrite=NOERROR;A;${lanAnswer},client=127.0.0.1|::1"
    ];

  autoSplitDomains = optionals (cfg.domain != null) (
    [cfg.domain]
    ++ optionals (adg.arrDomain != null && !lib.hasSuffix ".${cfg.domain}" adg.arrDomain && adg.arrDomain != cfg.domain) [adg.arrDomain]
  );

  uniformRewrites =
    lib.concatMap (
      r:
        if r.answer != null
        then
          [
            {
              inherit (r) domain answer;
              enabled = true;
            }
          ]
          ++ lib.optional r.includeSubdomains {
            domain = "*.${r.domain}";
            inherit (r) answer;
            enabled = true;
          }
        else []
    )
    cfg.adguard.rewrites;

  singleIpFallback =
    if cfg.adguard.tailscaleIp == null && cfg.adguard.lanIp != null
    then cfg.adguard.lanIp
    else if cfg.adguard.lanIp == null && cfg.adguard.tailscaleIp != null
    then cfg.adguard.tailscaleIp
    else null;

  autoSingleRewrites = optionals (singleIpFallback != null && cfg.domain != null) (
    [
      {
        domain = "*.${cfg.domain}";
        answer = singleIpFallback;
        enabled = true;
      }
      {
        domain = cfg.domain;
        answer = singleIpFallback;
        enabled = true;
      }
    ]
    ++ optionals (adg.arrDomain != null && adg.arrDomain != cfg.domain) [
      {
        domain = "*.${adg.arrDomain}";
        answer = singleIpFallback;
        enabled = true;
      }
      {
        domain = adg.arrDomain;
        answer = singleIpFallback;
        enabled = true;
      }
    ]
  );

  customSplitUserRules =
    lib.concatMap (
      r:
        if r.answer == null
        then
          mkSplitUserRules {
            inherit (r) domain lanAnswer tailscaleAnswer includeSubdomains;
          }
        else []
    )
    cfg.adguard.rewrites;

  rewriteAssertions =
    map (r: let
      hasUniform = r.answer != null;
      hasSplit = r.lanAnswer != null || r.tailscaleAnswer != null;
    in {
      assertion = (hasUniform != hasSplit) && (hasUniform || hasSplit);
      message = "server.adguard.rewrites (${r.domain}): specify either 'answer' OR at least one of 'lanAnswer' / 'tailscaleAnswer' (not both).";
    })
    cfg.adguard.rewrites;

  pythonWithBcrypt = pkgs.python3.withPackages (ps: [
    ps.bcrypt
    ps.pyyaml
  ]);

  syncAdminScript = pkgs.writeShellApplication {
    name = "adguardhome-admin-sync";
    runtimeInputs = [pythonWithBcrypt];
    text = ''
      exec python3 ${./scripts/sync-admin.py} \
        --config "/var/lib/AdGuardHome/AdGuardHome.yaml" \
        --secret "${toString cfg.adguard.passwordSecret}" \
        --username "${cfg.adguard.adminUser}"
    '';
  };

  watchdogScript = pkgs.writeShellApplication {
    name = "adguardhome-watchdog";
    runtimeInputs = with pkgs; [
      systemd
      curl
      python3
      coreutils
    ];
    runtimeEnv =
      adg.commonEnv
      // {
        FAILURE_THRESHOLD = toString cfg.adguard.watchdog.failureThreshold;
      };
    text = builtins.readFile ./scripts/watchdog.sh;
  };
in {
  # Automatically ignore router DHCP DNS on the AdGuard host so the server never
  # loops host lookups back to its own LAN IP via DHCP.
  options.systemd.network.networks = lib.mkOption {
    type = lib.types.attrsOf (
      lib.types.submodule (netArgs: let
        dhcpMode = netArgs.config.networkConfig.DHCP or "no";
        hasDhcp = dhcpMode != "no" && dhcpMode != null && dhcpMode != false;
        isUnmanaged = netArgs.config.linkConfig.Unmanaged or false;
      in {
        config = mkIf (cfg.enable && cfg.adguard.enable && !isUnmanaged && hasDhcp) {
          dhcpV4Config.UseDNS = mkDefault false;
          dhcpV6Config.UseDNS = mkDefault false;
        };
      })
    );
  };

  config = mkIf (cfg.enable && cfg.adguard.enable) {
    # -------------------------------------------------------------------------
    # Configuration Sanity Assertions
    # -------------------------------------------------------------------------
    assertions =
      [
        {
          assertion = config.sops.secrets ? services_password;
          message = "server.adguard: config.sops.secrets.services_password must be defined in your secrets file.";
        }
        {
          assertion = !cfg.adguard.bypassSystemVpn || !adg.systemVpnEnabled || adg.systemVpnBypassActive;
          message = "server.adguard: 'bypassSystemVpn = true' requires 'networking.systemVPN.bypass.enable = true'.";
        }
      ]
      ++ rewriteAssertions;

    sops.secrets.services_password = {
      restartUnits = ["adguardhome-admin-sync.service" "adguardhome.service"];
    };

    # Keep independent host fallback resolvers when ignoring router DHCP DNS
    networking.nameservers = mkDefault ["1.1.1.1" "1.0.0.1"];

    # Open DNS port 53 (TCP & UDP) for LAN and Tailscale clients
    networking.firewall.allowedTCPPorts = [53];
    networking.firewall.allowedUDPPorts = [53];

    # Disable systemd-resolved DNSStubListener on 127.0.0.53:53 so AdGuard can bind 0.0.0.0:53
    services.resolved.settings = {
      Resolve = {
        DNSStubListener = "no";
      };
    };

    # -------------------------------------------------------------------------
    # Systemd Services, VPN Ordering, Resource Limits & Watchdog
    # -------------------------------------------------------------------------
    systemd.services = {
      adguardhome-admin-sync = {
        description = "Synchronize AdGuard Home admin credentials from SOPS";
        after = ["sops-nix.service"];
        before = ["adguardhome.service"];
        requiredBy = ["adguardhome.service"];
        wantedBy = ["multi-user.target"];

        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          PrivateTmp = true;
          ProtectHome = true;
          NoNewPrivileges = true;
          ExecStart = "${syncAdminScript}/bin/adguardhome-admin-sync";
        };
      };

      adguardhome = let
        waitSystemVpn = adg.systemVpnEnabled && !cfg.adguard.bypassSystemVpn;
        vpnUnit = "wg-quick-${adg.systemVpnIface}.service";
      in {
        wants = optional waitSystemVpn vpnUnit;
        after = optional waitSystemVpn vpnUnit;

        serviceConfig = {
          Group = mkIf (cfg.adguard.bypassSystemVpn && adg.systemVpnBypassActive) adg.systemVpnBypassGroup;
          # 1.7M+ filter rules peak near ~1 GiB during reload/compilation
          MemoryHigh = "1G";
          MemoryMax = "1536M";
        };

        unitConfig = {
          StartLimitIntervalSec = lib.mkForce 0;
        };
      };

      adguardhome-watchdog = mkIf cfg.adguard.watchdog.enable {
        description = "Health check and auto-recovery for AdGuard Home";
        serviceConfig = {
          Type = "oneshot";
          RuntimeDirectory = "adguard-watchdog";
          RuntimeDirectoryPreserve = "yes";
          ExecStart = "${watchdogScript}/bin/adguardhome-watchdog";
        };
      };
    };

    systemd.timers.adguardhome-watchdog = mkIf cfg.adguard.watchdog.enable {
      description = "Timer for AdGuard Home WebUI & DNS health check";
      wantedBy = ["timers.target"];
      timerConfig = {
        OnBootSec = "2m";
        OnUnitActiveSec = cfg.adguard.watchdog.interval;
        RandomizedDelaySec = "10s";
      };
    };

    # -------------------------------------------------------------------------
    # AdGuard Home Native NixOS Service Configuration
    # -------------------------------------------------------------------------
    services.adguardhome = {
      enable = true;
      mutableSettings = true;
      settings = {
        http.address = "127.0.0.1:${toString cfg.adguard.port}";
        querylog = {
          interval = cfg.adguard.querylogInterval;
        };
        dns = {
          bind_hosts = ["0.0.0.0"];
          port = 53;
          upstream_dns = cfg.adguard.upstreamDns;
          fallback_dns = cfg.adguard.fallbackDns;
          bootstrap_dns = [
            "9.9.9.9"
            "1.1.1.1"
            "149.112.112.112"
            "1.0.0.1"
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
          ratelimit_whitelist = [
            "127.0.0.1"
            "::1"
          ];
          use_private_ptr_resolvers = true;
          local_ptr_upstreams = [cfg.adguard.routerIp];
          # Prevent NixOS-generated /etc/hosts loopback entries (e.g. Caddy vhosts) from leaking 127.0.0.x to LAN/Tailscale clients
          hostsfile_enabled = false;
          trusted_proxies = [
            "127.0.0.0/8"
            "::1/128"
          ];
        };
        filtering = {
          protection_enabled = true;
          filtering_enabled = true;
          rewrites_enabled = true;
          rewrites = autoSingleRewrites ++ uniformRewrites;
        };
        user_rules =
          optionals (cfg.adguard.tailscaleIp != null && cfg.adguard.lanIp != null) (
            lib.concatMap (
              domain:
                mkSplitUserRules {
                  inherit domain;
                  lanAnswer = cfg.adguard.lanIp;
                  tailscaleAnswer = cfg.adguard.tailscaleIp;
                }
            )
            autoSplitDomains
          )
          ++ customSplitUserRules;
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
