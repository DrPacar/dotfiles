{
  config,
  lib,
  ...
}: let
  inherit (lib) mkEnableOption mkOption types;
  cfg = config.networking.shares;
in {
  options.networking.shares = {
    enable = mkEnableOption "declarative CIFS/SMB network shares with on-demand automounting, local symlink fast-path, and CLI diagnostics";

    cli.enable = mkOption {
      type = types.bool;
      default = true;
      description = "Install the unified 'shares' status, verification, and mount control CLI.";
    };

    defaultUser = mkOption {
      type = types.str;
      default = config.user.primary or "root";
      description = "Default local Linux username used for mount ownership and home directory symlinks.";
    };

    entries = mkOption {
      type = types.attrsOf (types.submodule ({name, ...}: {
        options = {
          enable = mkOption {
            type = types.bool;
            default = true;
            description = "Enable this share entry.";
          };

          host = mkOption {
            type = types.nullOr types.str;
            default = null;
            example = "fileserver.local";
            description = "Hostname or IP address of the remote SMB/CIFS server (required unless isLocal = true).";
          };

          shareName = mkOption {
            type = types.str;
            default = name;
            description = "Remote SMB share name exported by the server.";
          };

          mountPoint = mkOption {
            type = types.str;
            default = "/mnt/${name}";
            description = "Local directory path where the remote CIFS share is automounted.";
          };

          localPath = mkOption {
            type = types.nullOr types.str;
            default = null;
            example = "/srv/share";
            description = "Local filesystem path to symlink directly instead of mounting over CIFS when running on the server itself.";
          };

          isLocal = mkOption {
            type = types.bool;
            default = false;
            description = "Explicitly treat this host as the local share server and bypass CIFS mounting in favor of localPath.";
          };

          symlink = {
            enable = mkOption {
              type = types.bool;
              default = false;
              description = "Create a declarative symlink pointing to the share mount (or localPath when local).";
            };

            path = mkOption {
              type = types.nullOr types.str;
              default = null;
              example = "/home/alice/share";
              description = "Target symlink path. When null and symlink.enable is true, defaults to '<userHome>/<shareName>'.";
            };
          };

          user = mkOption {
            type = types.str;
            default = cfg.defaultUser;
            description = "Local Linux username owning the CIFS mount and optional symlink.";
          };

          group = mkOption {
            type = types.nullOr types.str;
            default = null;
            description = "Local Linux group name for CIFS gid mapping. When null, uses the configured user's primary group.";
          };

          credentialsFile = mkOption {
            type = types.nullOr types.str;
            default = null;
            description = ''
              Filesystem path (string, not a Nix store path literal) to a CIFS credentials file.
              Uses guest authentication when null.
            '';
          };

          smbVersion = mkOption {
            type = types.str;
            default = "3.1.1";
            description = "SMB protocol dialect passed to mount.cifs (e.g. '3.1.1', '3.0', '2.1').";
          };

          softMount = mkOption {
            type = types.bool;
            default = true;
            description = "Use 'soft' CIFS mount semantics so I/O fails cleanly instead of hanging indefinitely when the server becomes unreachable.";
          };

          idleTimeout = mkOption {
            type = types.ints.unsigned;
            default = 60;
            description = "Seconds of inactivity before systemd automount unmounts the CIFS share (0 disables idle unmount).";
          };

          mountTimeout = mkOption {
            type = types.ints.positive;
            default = 5;
            description = "Seconds before systemd times out a mount attempt to an unreachable server.";
          };

          fileMode = mkOption {
            type = types.str;
            default = "0664";
            description = "POSIX file mode applied to mounted CIFS files.";
          };

          dirMode = mkOption {
            type = types.str;
            default = "0775";
            description = "POSIX directory mode applied to mounted CIFS directories.";
          };

          readOnly = mkOption {
            type = types.bool;
            default = false;
            description = "Mount the remote share read-only.";
          };

          extraOptions = mkOption {
            type = types.listOf types.str;
            default = [];
            description = "Additional mount options passed verbatim to mount.cifs.";
          };
        };
      }));
      default = {};
      description = "Declarative map of SMB/CIFS shares to automount or locally symlink.";
    };
  };
}
