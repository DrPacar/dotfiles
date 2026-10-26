{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (lib) mkIf mkOption types;
  cfg = config.client.shares.data;

  isLocalServer = config.networking.hostName == cfg.serverHost;
  targetPath =
    if (isLocalServer && !cfg.forceNetworkMount)
    then "/data"
    else cfg.mountPoint;

  userUid =
    if config.users.users.${cfg.user}.uid != null
    then toString config.users.users.${cfg.user}.uid
    else "1000";
in {
  options.client.shares.data = {
    enable = mkOption {
      type = types.bool;
      default = false;
      description = "Enable automatic on-demand mounting of central /data share.";
    };

    serverHost = mkOption {
      type = types.str;
      default = "lighthouse";
      description = "Hostname or IP address of the Samba server (works locally and via Tailscale).";
    };

    shareName = mkOption {
      type = types.str;
      default = "data";
      description = "Samba share name on the server.";
    };

    mountPoint = mkOption {
      type = types.str;
      default = "/mnt/data";
      description = "Local path where the CIFS network share will be mounted.";
    };

    createHomeSymlink = mkOption {
      type = types.bool;
      default = true;
      description = "Create a convenient symlink ~/data pointing to the data share.";
    };

    user = mkOption {
      type = types.str;
      default = config.user.primary or "luka";
      description = "User whose home directory will contain the symlink and own the mount.";
    };

    credentialsFile = mkOption {
      type = types.nullOr types.path;
      default = null;
      description = "Optional path to a credentials file containing username and password. If null, guest access is used.";
    };

    forceNetworkMount = mkOption {
      type = types.bool;
      default = false;
      description = "Force CIFS network mounting even if running on the host defined in serverHost.";
    };
  };

  config = mkIf cfg.enable {
    # Ensure CIFS mount tools are available
    environment.systemPackages = [pkgs.cifs-utils];

    # Configure CIFS network automount (only on remote clients unless forced)
    fileSystems = mkIf (!isLocalServer || cfg.forceNetworkMount) {
      "${cfg.mountPoint}" = {
        device = "//${cfg.serverHost}/${cfg.shareName}";
        fsType = "cifs";
        options = [
          # 1. On-demand mounting: never blocks boot, even when offline
          "x-systemd.automount"
          "noauto"
          # 2. Idle timeout: unmounts after 60s of inactivity (battery saving & sleep/resume safe)
          "x-systemd.idle-timeout=60"
          # 3. Fast failure: 5s timeout if server is unreachable
          "x-systemd.mount-timeout=5"
          # 4. Network device flag
          "_netdev"
          # 5. Local user and permission mapping
          "uid=${userUid}"
          "gid=100"
          "file_mode=0664"
          "dir_mode=0775"
          # 6. Authentication
          (
            if cfg.credentialsFile != null
            then "credentials=${toString cfg.credentialsFile}"
            else "guest"
          )
        ];
      };
    };

    # Convenient home directory symlink ~/data -> target directory
    systemd.tmpfiles.rules = mkIf cfg.createHomeSymlink [
      "L+ /home/${cfg.user}/data - - - - ${targetPath}"
    ];
  };
}
