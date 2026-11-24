{
  config,
  lib,
  ...
}: let
  inherit (lib) concatMapStringsSep concatStringsSep filter hasInfix mkIf optionals;
  cfg = config.networking.systemVPN;
  vpn = import ./_lib.nix {inherit config lib;};

  # Partition LAN subnets into IPv4 and IPv6 lists for type-safe nftables matching
  ipv4LanSubnets = filter (s: !hasInfix ":" s) cfg.lanSubnets;
  ipv6LanSubnets = filter (s: hasInfix ":" s) cfg.lanSubnets;

  # Separate exact interface names from wildcard patterns (e.g. "br-*", "veth-*");
  # nftables sets do not reliably match wildcards across versions.
  isWild = hasInfix "*";
  exactIfaces = filter (i: !isWild i) vpn.allowedInterfaces;
  wildIfaces = filter isWild vpn.allowedInterfaces;

  # Shared rule fragments reused by both output_killswitch and forward_killswitch
  ifaceAcceptRules =
    optionals (exactIfaces != []) [
      "oifname { ${concatMapStringsSep ", " (i: "\"${i}\"") exactIfaces} } accept;"
    ]
    ++ map (i: "oifname \"${i}\" accept;") wildIfaces;

  lanAcceptRules =
    optionals (ipv4LanSubnets != []) [
      "oifname \"${vpn.physIface}\" ip daddr { ${concatStringsSep ", " ipv4LanSubnets} } accept;"
    ]
    ++ optionals (ipv6LanSubnets != []) [
      "oifname \"${vpn.physIface}\" ip6 daddr { ${concatStringsSep ", " ipv6LanSubnets} } accept;"
    ];

  renderRules = rules: concatMapStringsSep "\n" (r: "  " + r) rules;

  mangleRules =
    optionals vpn.bypassActive [
      "meta skgid ${toString vpn.bypassGid} meta mark 0 meta mark set ${vpn.bypassFwmark};"
    ]
    ++ [
      "oifname \"${cfg.interfaceName}\" meta mark != ${vpn.bypassFwmark} tcp flags syn / syn,rst tcp option maxseg size set rt mtu;"
    ];

  postroutingRules = optionals vpn.bypassActive [
    "oifname \"${vpn.physIface}\" meta mark ${vpn.bypassFwmark} masquerade;"
  ];

  outputKillswitchRules =
    ifaceAcceptRules
    ++ optionals vpn.bypassActive [
      "oifname \"${vpn.physIface}\" meta mark ${vpn.bypassFwmark} accept;"
    ]
    ++ optionals vpn.tsActive [
      "oifname \"${vpn.physIface}\" meta mark & 0xff0000 == 0x80000 accept;"
    ]
    ++ lanAcceptRules
    ++ [
      "oifname \"${vpn.physIface}\" ip daddr { 224.0.0.0/4, 255.255.255.255 } accept;"
      "oifname \"${vpn.physIface}\" ip6 daddr { fe80::/10, ff00::/8 } accept;"
      "oifname \"${vpn.physIface}\" udp sport 67-68 udp dport 67-68 accept;"
      "oifname \"${vpn.physIface}\" meta mark ${vpn.wgFwmark} accept;"
      "counter name \"killswitch_reject\" reject with icmpx type admin-prohibited;"
    ];

  forwardKillswitchRules =
    ifaceAcceptRules
    ++ lanAcceptRules
    ++ [
      "counter name \"forward_killswitch_reject\" reject with icmpx type admin-prohibited;"
    ];
in {
  config = mkIf cfg.enable {
    # Loose reverse path filtering prevents dropping asymmetric response packets from bypass traffic
    networking.firewall.checkReversePath = "loose";

    networking.nftables = {
      enable = true;

      tables."system-vpn" = {
        family = "inet";
        content = ''
          # Named counters for deterministic telemetry & selftest verification
          counter killswitch_reject {}
          counter forward_killswitch_reject {}

          # Marks bypass sockets before routing and clamps TCP MSS on the VPN interface
          chain output_mangle {
            type route hook output priority mangle; policy accept;
          ${renderRules mangleRules}
          }

          # Masquerades split-tunnel bypass traffic exiting the physical LAN interface
          chain postrouting_nat {
            type nat hook postrouting priority srcnat; policy accept;
          ${renderRules postroutingRules}
          }

          # Host egress filter (priority filter - 5 evaluates before nixos-fw)
          chain output_killswitch {
            type filter hook output priority filter - 5; policy accept;
          ${renderRules outputKillswitchRules}
          }

          # Container / VM forward filter preventing unencrypted WAN leaks
          chain forward_killswitch {
            type filter hook forward priority filter - 5; policy accept;
          ${renderRules forwardKillswitchRules}
          }
        '';
      };
    };
  };
}
