{lib, ...}: let
  inherit (lib) mkOption types;
in {
  options.server.arr.sonarr = {
    enable = mkOption {
      type = types.bool;
      default = true;
      description = "Enable Sonarr TV series manager.";
    };

    port = mkOption {
      type = types.port;
      default = 8989;
      description = "Port for Sonarr web interface.";
    };

    subdomain = mkOption {
      type = types.str;
      default = "sonarr";
      description = "Subdomain name for Sonarr reverse proxy routing.";
    };

    fileDate = mkOption {
      type = types.enum [
        "none"
        "localAirDate"
        "utcAirDate"
      ];
      default = "localAirDate";
      description = "Set the file date on imported series episode files.";
    };

    anime = {
      enable = mkOption {
        type = types.bool;
        default = false;
        description = "Enable separate Sonarr Anime instance for dedicated anime management (disabled by default in favor of unified Sonarr).";
      };

      port = mkOption {
        type = types.port;
        default = 8990;
        description = "Port for Sonarr Anime web interface.";
      };

      subdomain = mkOption {
        type = types.str;
        default = "anime";
        description = "Subdomain name for Sonarr Anime reverse proxy routing.";
      };
    };
  };
}
