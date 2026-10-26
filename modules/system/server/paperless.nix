{
  config,
  lib,
  ...
}: let
  inherit (lib) mkIf mkOption types;
  cfg = config.server;

  externalUrl =
    if cfg.domain != null
    then "https://${cfg.paperless.subdomain}.${cfg.domain}"
    else "http://127.0.0.1:${toString cfg.paperless.port}";
in {
  options.server.paperless = {
    enable = mkOption {
      type = types.bool;
      default = false;
      description = "Enable Paperless-ngx self-hosted document management system.";
    };

    port = mkOption {
      type = types.port;
      default = 28981;
      description = "Internal HTTP port on which Paperless web server listens.";
    };

    subdomain = mkOption {
      type = types.str;
      default = "paperless";
      description = "Primary subdomain for Paperless (e.g. paperless.media.lukpac.dev).";
    };

    dataDir = mkOption {
      type = types.path;
      default = "/var/lib/paperless";
      description = "Directory to store Paperless database, search index, and configuration.";
    };

    mediaDir = mkOption {
      type = types.path;
      default = "/var/lib/paperless/media";
      description = "Directory to store the original and archived PDF documents.";
    };

    consumptionDir = mkOption {
      type = types.path;
      default = "/var/lib/paperless/consume";
      description = "Directory watched by the consumer for newly scanned or dropped documents.";
    };

    consumptionDirIsPublic = mkOption {
      type = types.bool;
      default = true;
      description = "Whether to allow other users to write new files into the consumption folder.";
    };

    ocrLanguage = mkOption {
      type = types.str;
      default = "deu+eng";
      description = "Tesseract OCR languages to enable for document scanning (e.g. deu+eng).";
    };

    passwordFile = mkOption {
      type = types.nullOr types.path;
      default = null;
      description = "Optional file containing the initial admin password. If unset, superuser is created via paperless-manage.";
    };

    extraSettings = mkOption {
      type = types.attrsOf types.anything;
      default = {};
      description = "Extra Paperless settings passed to services.paperless.settings.";
    };
  };

  config = mkIf (cfg.enable && cfg.paperless.enable) {
    services.paperless = {
      enable = true;
      address = "127.0.0.1";
      port = cfg.paperless.port;
      dataDir = cfg.paperless.dataDir;
      mediaDir = cfg.paperless.mediaDir;
      consumptionDir = cfg.paperless.consumptionDir;
      consumptionDirIsPublic = cfg.paperless.consumptionDirIsPublic;
      passwordFile = mkIf (cfg.paperless.passwordFile != null) cfg.paperless.passwordFile;

      settings =
        {
          PAPERLESS_URL = externalUrl;
          PAPERLESS_OCR_LANGUAGE = cfg.paperless.ocrLanguage;
          PAPERLESS_OCR_USER_ARGS = {
            optimize = 1;
            pdfa_image_compression = "lossless";
          };
        }
        // cfg.paperless.extraSettings;
    };
  };
}
