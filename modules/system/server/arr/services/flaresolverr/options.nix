{lib, ...}: let
  inherit (lib) mkOption types;
in {
  options.server.arr.flaresolverr = {
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

    host = mkOption {
      type = types.str;
      default = "127.0.0.1";
      description = "Network host address to bind FlareSolverr to.";
    };

    subdomain = mkOption {
      type = types.str;
      default = "flaresolverr";
      description = "Subdomain name for FlareSolverr reverse proxy routing.";
    };

    disableMedia = mkOption {
      type = types.bool;
      default = true;
      description = "Block images, stylesheets and fonts during browser automation to minimize RAM and accelerate challenge solving.";
    };

    memoryHigh = mkOption {
      type = types.str;
      default = "768M";
      description = "Systemd MemoryHigh threshold to trigger aggressive memory reclamation on Chromium processes.";
    };

    memoryMax = mkOption {
      type = types.str;
      default = "1200M";
      description = "Systemd MemoryMax limit to protect the host against Chromium memory leaks.";
    };
  };
}
