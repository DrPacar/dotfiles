{
  config,
  lib,
  ...
}: let
  inherit (lib) mkIf mkOption types;
  cfg = config.server;
in {
  options.server.uptime-kuma = {
    enable = mkOption {
      type = types.bool;
      default = false;
      description = "Enable Uptime Kuma monitoring and status page service.";
    };

    port = mkOption {
      type = types.port;
      default = 3001;
      description = "Internal HTTP port on which Uptime Kuma listens.";
    };

    subdomain = mkOption {
      type = types.str;
      default = "status";
      description = "Subdomain for Uptime Kuma (e.g. status.media.lukpac.dev).";
    };
  };

  config = mkIf (cfg.enable && cfg.uptime-kuma.enable) {
    services.uptime-kuma = {
      enable = true;
      settings = {
        PORT = toString cfg.uptime-kuma.port;
        HOST = "127.0.0.1";
      };
    };
  };
}
