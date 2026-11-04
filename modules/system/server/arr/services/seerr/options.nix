{
  config,
  lib,
  ...
}: let
  inherit (lib) mkOption types;
in {
  options.server.arr.seerr = {
    enable = mkOption {
      type = types.bool;
      default = true;
      description = "Enable Seerr (Jellyseerr) media request interface.";
    };

    port = mkOption {
      type = types.port;
      default = 5055;
      description = "Port for Seerr web interface.";
    };

    subdomain = mkOption {
      type = types.str;
      default = "seerr";
      description = "Subdomain name for Seerr reverse proxy routing.";
    };

    defaultMovieProfile = mkOption {
      type = types.str;
      default = "Full HD (1080p) – Englisch";
      description = "Default quality profile assigned to new movie requests.";
    };

    defaultSeriesProfile = mkOption {
      type = types.str;
      default = "Full HD (1080p) – Englisch";
      description = "Default quality profile assigned to new TV series requests.";
    };

    defaultAnimeProfile = mkOption {
      type = types.str;
      default = "Anime (1080p) – Japanisch (Sub)";
      description = "Default quality profile assigned to new anime requests.";
    };

    defaultPermissions = mkOption {
      type = types.int;
      default = 120;
      description = ''
        Default user permission bitmask in Jellyseerr.
        REQUEST (32) + REQUEST_ADVANCED (16) + AUTO_APPROVE_MOVIE (64) + AUTO_APPROVE_TV (8) = 120.
        Automatically approves 1080p requests within quota; 4K requests require manual approval.
      '';
    };

    defaultQuotas = {
      movie = {
        quotaLimit = mkOption {
          type = types.int;
          default = 3;
          description = "Maximum number of movie requests per user quota period.";
        };

        quotaDays = mkOption {
          type = types.int;
          default = 7;
          description = "Rolling quota period in days for movie requests.";
        };
      };

      tv = {
        quotaLimit = mkOption {
          type = types.int;
          default = 1;
          description = "Maximum number of TV series requests per user quota period.";
        };

        quotaDays = mkOption {
          type = types.int;
          default = 7;
          description = "Rolling quota period in days for TV series requests.";
        };
      };
    };
  };
}
