{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (lib) boolToString mkIf mkOption types;
  isServer = config.server.enable or false;
  cfg = config.client.tailscale;
in {
  options.client.tailscale = {
    acceptDns = mkOption {
      type = types.bool;
      default = true;
      description = "Whether this client accepts Tailnet DNS overrides (e.g. AdGuard DNS via haven).";
    };

    acceptRoutes = mkOption {
      type = types.bool;
      default = false;
      description = "Whether this client accepts subnet routes advertised by other Tailscale nodes.";
    };
  };

  config = mkIf (!isServer) {
    services.tailscale = {
      enable = true;
      openFirewall = true;

      # Allow asymmetric routing / exit nodes without enabling IP forwarding
      useRoutingFeatures = "client";

      extraSetFlags = [
        "--operator=${config.user.primary}"
        "--accept-dns=${boolToString cfg.acceptDns}"
        "--accept-routes=${boolToString cfg.acceptRoutes}"
      ];
    };

    # Trust tailscale0 on clients for seamless access between personal devices
    networking.firewall.trustedInterfaces = [config.services.tailscale.interfaceName];

    environment.systemPackages = with pkgs; [
      trayscale
    ];
  };
}
