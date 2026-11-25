{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (lib) boolToString mkEnableOption mkIf mkOption types;
  cfg = config.client.tailscale;
in {
  options.client.tailscale = {
    enable = mkEnableOption "Tailscale client profile with desktop tray GUI and Tailnet DNS support";

    operator = mkOption {
      type = types.nullOr types.str;
      default = config.user.primary or null;
      description = "Local Unix username allowed to operate Tailscale without sudo.";
    };

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

  config = mkIf cfg.enable {
    services.tailscale = {
      enable = true;
      openFirewall = true;

      # Allow asymmetric routing / exit nodes without enabling IP forwarding
      useRoutingFeatures = "client";

      extraSetFlags =
        lib.optional (cfg.operator != null) "--operator=${cfg.operator}"
        ++ [
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
