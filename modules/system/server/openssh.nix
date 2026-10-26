{
  config,
  lib,
  ...
}: let
  inherit (lib) mkIf mkOption types;
  cfg = config.server;
in {
  options.server.openssh = {
    enable = mkOption {
      type = types.bool;
      default = false;
      description = "Enable hardened OpenSSH daemon for remote server access.";
    };

    port = mkOption {
      type = types.port;
      default = 22;
      description = "Port on which OpenSSH daemon listens.";
    };

    openFirewall = mkOption {
      type = types.bool;
      default = true;
      description = "Whether to automatically open the SSH port in the firewall.";
    };

    authorizedKeys = mkOption {
      type = types.listOf types.str;
      default = [
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIEK+FcUtXmUuiDkdlye5eDnlWipnPwzQmBFVGogWvUlM luka@raindrop"
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAII9ahMh0Tcn58e2gANWRpyECO/zGO/At2tk7eD70KGxl luka@lighthouse"
      ];
      description = "Authorized SSH public keys for the admin user.";
    };

    allowPasswords = mkOption {
      type = types.bool;
      default = false;
      description = "Whether to allow password authentication (disabled by default for security).";
    };
  };

  config = mkIf (cfg.enable && cfg.openssh.enable) {
    services.openssh = {
      enable = true;
      ports = [cfg.openssh.port];
      openFirewall = cfg.openssh.openFirewall;

      settings = {
        PasswordAuthentication = cfg.openssh.allowPasswords;
        KbdInteractiveAuthentication = false;
        PermitRootLogin = "no";
        X11Forwarding = false;
      };
    };

    users.users.${cfg.adminUser}.openssh.authorizedKeys.keys = cfg.openssh.authorizedKeys;
  };
}
