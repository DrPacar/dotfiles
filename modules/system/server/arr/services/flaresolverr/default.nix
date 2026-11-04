{
  config,
  lib,
  ...
}: let
  inherit (lib) mkIf;
  cfg = config.server.arr;
in {
  config = mkIf (cfg.enable && cfg.flaresolverr.enable) {
    nixflix.flaresolverr = {
      enable = true;
      port = cfg.flaresolverr.port;
    };

    systemd.services.flaresolverr = {
      environment = {
        HOST = cfg.flaresolverr.host;
        PORT = toString cfg.flaresolverr.port;
        TZ = config.time.timeZone or "Europe/Vienna";
        LOG_LEVEL = "info";
        LOG_HTML = "false";
        CAPTCHA_SOLVER = "none";
        DISABLE_MEDIA =
          if cfg.flaresolverr.disableMedia
          then "true"
          else "false";
      };

      serviceConfig = {
        MemoryHigh = cfg.flaresolverr.memoryHigh;
        MemoryMax = cfg.flaresolverr.memoryMax;
        Slice = "arr.slice";
        Restart = "always";
        RestartSec = 5;
      };
    };
  };
}
