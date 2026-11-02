{
  config,
  lib,
  ...
}: let
  inherit (lib) mkOption types;
in {
  options.server = {
    enable = mkOption {
      type = types.bool;
      default = false;
      description = "Master switch to enable centralized server infrastructure and all server services (Caddy, Arr stack, Immich, Paperless, etc.). When false, all server modules are disabled.";
    };

    adminUser = mkOption {
      type = types.str;
      default = config.user.primary or "luka";
      description = "Primary administrator username for server services.";
    };

    domain = mkOption {
      type = types.nullOr types.str;
      default = "lukpac.dev";
      description = "Public domain used for Caddy reverse proxy and wildcard SSL certificates.";
    };

    tailscaleDomain = mkOption {
      type = types.nullOr types.str;
      default = "gute-court.ts.net";
      description = "Tailscale tailnet domain suffix for authorized host access.";
    };
  };
}
