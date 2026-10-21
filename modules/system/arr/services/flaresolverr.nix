{
  config,
  lib,
  ...
}: let
  inherit (lib) mkOption mkIf types;
  cfg = config.arr;
in {
  options.arr.flaresolverr = {
    enable = mkOption {
      type = types.bool;
      default = true;
      description = "Enable FlareSolverr proxy for bypassing Cloudflare on indexers.";
    };

    port = mkOption {
      type = types.port;
      default = 8191;
      description = "Port for FlareSolverr service.";
    };

    subdomain = mkOption {
      type = types.str;
      default = "flaresolverr";
      description = "Subdomain name for FlareSolverr reverse proxy routing.";
    };
  };

  config = mkIf (cfg.enable && cfg.flaresolverr.enable) {
    nixflix.flaresolverr = {
      enable = true;
      port = cfg.flaresolverr.port;
    };
  };
}
