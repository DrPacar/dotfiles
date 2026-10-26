{
  config,
  lib,
  ...
}: let
  inherit (lib) mkIf mkOption types;
  cfg = config.server;

  vaultUrl =
    if cfg.domain != null
    then "https://${cfg.vaultwarden.subdomain}.${cfg.domain}"
    else "http://127.0.0.1:${toString cfg.vaultwarden.port}";
in {
  options.server.vaultwarden = {
    enable = mkOption {
      type = types.bool;
      default = false;
      description = "Enable Vaultwarden lightweight Bitwarden-compatible password manager.";
    };

    port = mkOption {
      type = types.port;
      default = 8222;
      description = "Internal HTTP port on which Vaultwarden listens.";
    };

    subdomain = mkOption {
      type = types.str;
      default = "vault";
      description = "Primary subdomain for Vaultwarden (e.g. vault.media.lukpac.dev).";
    };

    signupsAllowed = mkOption {
      type = types.bool;
      default = true;
      description = "Whether new user registrations are permitted. Can be set to false once initial accounts are created.";
    };

    environmentFile = mkOption {
      type = types.nullOr types.path;
      default = null;
      description = "Optional environment file containing secrets (such as ADMIN_TOKEN).";
    };
  };

  config = mkIf (cfg.enable && cfg.vaultwarden.enable) {
    services.vaultwarden = {
      enable = true;
      environmentFile = mkIf (cfg.vaultwarden.environmentFile != null) cfg.vaultwarden.environmentFile;
      config = {
        DOMAIN = vaultUrl;
        ROCKET_ADDRESS = "127.0.0.1";
        ROCKET_PORT = cfg.vaultwarden.port;
        SIGNUPS_ALLOWED = cfg.vaultwarden.signupsAllowed;
      };
    };
  };
}
