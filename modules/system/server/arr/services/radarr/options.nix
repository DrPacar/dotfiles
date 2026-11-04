{lib, ...}: let
  inherit (lib) mkOption types;
in {
  options.server.arr.radarr = {
    enable = mkOption {
      type = types.bool;
      default = true;
      description = "Enable Radarr movie manager.";
    };

    port = mkOption {
      type = types.port;
      default = 7878;
      description = "Port for Radarr web interface.";
    };

    subdomain = mkOption {
      type = types.str;
      default = "radarr";
      description = "Subdomain name for Radarr reverse proxy routing.";
    };

    fileDate = mkOption {
      type = types.enum [
        "none"
        "cinemas"
        "physical"
        "digital"
      ];
      default = "cinemas";
      description = "Set the file date on imported movie files.";
    };
  };
}
