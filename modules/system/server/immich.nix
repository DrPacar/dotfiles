{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (lib) mkIf mkOption types;
  cfg = config.server;

  externalUrl =
    if cfg.domain != null
    then "https://${cfg.immich.subdomain}.${cfg.domain}"
    else "http://127.0.0.1:${toString cfg.immich.port}";
in {
  options.server.immich = {
    enable = mkOption {
      type = types.bool;
      default = false;
      description = "Enable Immich self-hosted photo and video backup and management solution.";
    };

    port = mkOption {
      type = types.port;
      default = 2283;
      description = "Internal HTTP port on which Immich server listens.";
    };

    subdomain = mkOption {
      type = types.str;
      default = "immich";
      description = "Primary subdomain for Immich (e.g. immich.media.lukpac.dev).";
    };

    mediaLocation = mkOption {
      type = types.path;
      default = "/var/lib/immich";
      description = "Filesystem path where Immich stores photos, videos, and thumbnails.";
    };

    hardwareAcceleration = mkOption {
      type = types.bool;
      default = true;
      description = "Enable hardware video transcoding via Intel QuickSync / VA-API.";
    };

    accelerationDevice = mkOption {
      type = types.nullOr types.str;
      default = "/dev/dri/renderD128";
      description = "Device path for hardware video transcoding.";
    };
  };

  config = mkIf (cfg.enable && cfg.immich.enable) {
    services.immich = {
      enable = true;
      host = "127.0.0.1";
      port = cfg.immich.port;
      mediaLocation = cfg.immich.mediaLocation;

      accelerationDevices = lib.optionals (cfg.immich.hardwareAcceleration && cfg.immich.accelerationDevice != null) [
        cfg.immich.accelerationDevice
      ];

      settings = {
        server.externalDomain = externalUrl;
      };
    };

    # Grant immich user access to hardware video acceleration devices
    users.users.immich.extraGroups = lib.optionals cfg.immich.hardwareAcceleration [
      "video"
      "render"
    ];

    # Ensure custom media location exists if configured differently from default
    systemd.tmpfiles.rules = mkIf (cfg.immich.mediaLocation != "/var/lib/immich") [
      "d ${cfg.immich.mediaLocation} 0750 immich immich -"
    ];
  };
}
