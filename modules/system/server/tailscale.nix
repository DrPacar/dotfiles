{
  config,
  lib,
  ...
}: let
  inherit (lib) boolToString mkIf mkOption types;
  cfg = config.server;
  tsCfg = cfg.tailscale;
in {
  options.server.tailscale = {
    enable = mkOption {
      type = types.bool;
      default = true;
      description = "Enable Tailscale daemon tuned for headless server operation.";
    };

    openFirewall = mkOption {
      type = types.bool;
      default = true;
      description = "Open the Tailscale UDP port (41641) in the firewall for direct P2P hole-punching.";
    };

    trustedInterface = mkOption {
      type = types.bool;
      default = true;
      description = "Add the Tailscale interface to trustedInterfaces so internal services are accessible over Tailnet.";
    };

    acceptDns = mkOption {
      type = types.bool;
      default = false;
      description = "Whether the server should accept Tailnet DNS overrides. Disabled by default so the server does not override its own AdGuard/WireGuard resolver setup.";
    };

    acceptRoutes = mkOption {
      type = types.bool;
      default = false;
      description = "Whether the server should accept subnet routes advertised by other Tailscale nodes.";
    };

    disableTaildrop = mkOption {
      type = types.bool;
      default = true;
      description = "Disable Taildrop file reception on headless servers.";
    };

    extraSetFlags = mkOption {
      type = types.listOf types.str;
      default = [];
      description = "Additional flags passed to 'tailscale set'.";
    };
  };

  config = mkIf (cfg.enable && tsCfg.enable) {
    services.tailscale = {
      enable = true;
      openFirewall = tsCfg.openFirewall;
      disableTaildrop = tsCfg.disableTaildrop;

      # Explicitly not a subnet router or exit node (keeps IP forwarding disabled),
      # while keeping loose reverse-path filtering compatible with multi-homed VPN/LAN links.
      useRoutingFeatures = "client";

      extraSetFlags =
        [
          "--operator=${cfg.adminUser}"
          "--accept-dns=${boolToString tsCfg.acceptDns}"
          "--accept-routes=${boolToString tsCfg.acceptRoutes}"
          "--advertise-exit-node=false"
          "--advertise-routes="
        ]
        ++ tsCfg.extraSetFlags;
    };

    networking.firewall.trustedInterfaces = mkIf tsCfg.trustedInterface [
      config.services.tailscale.interfaceName
    ];
  };
}
