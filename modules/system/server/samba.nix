{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (lib) mkIf mkOption types;
  cfg = config.server;

  shareToSamba = _name: shareCfg:
    {
      inherit (shareCfg) path comment;
      "read only" =
        if shareCfg.readOnly
        then "yes"
        else "no";
      browseable =
        if shareCfg.browseable
        then "yes"
        else "no";
      "guest ok" =
        if (cfg.samba.guestAccess && shareCfg.guestOk)
        then "yes"
        else "no";
      "create mask" = "0664";
      "directory mask" = "0775";
    }
    // lib.optionalAttrs (shareCfg.validUsers != []) {
      "valid users" = lib.concatStringsSep " " shareCfg.validUsers;
    }
    // lib.optionalAttrs (shareCfg.forceUser != null) {
      "force user" = shareCfg.forceUser;
    }
    // lib.optionalAttrs (shareCfg.forceGroup != null) {
      "force group" = shareCfg.forceGroup;
    }
    // shareCfg.extraConfig;
in {
  options.server.samba = {
    enable = mkOption {
      type = types.bool;
      default = false;
      description = "Enable Samba (SMB) file server for cross-device network file sharing.";
    };

    openFirewall = mkOption {
      type = types.bool;
      default = true;
      description = "Whether to automatically open Samba ports in the firewall.";
    };

    wsdd = mkOption {
      type = types.bool;
      default = true;
      description = "Enable Web Services Dynamic Discovery (wsdd) for automatic network discovery in Windows and GNOME/Nautilus.";
    };

    guestAccess = mkOption {
      type = types.bool;
      default = true;
      description = "Whether to globally permit guest access for shares where guestOk is true.";
    };

    shares = mkOption {
      type = types.attrsOf (types.submodule ({name, ...}: {
        options = {
          path = mkOption {
            type = types.path;
            description = "Filesystem path to the shared directory.";
          };

          readOnly = mkOption {
            type = types.bool;
            default = false;
            description = "Whether the share is read-only.";
          };

          browseable = mkOption {
            type = types.bool;
            default = true;
            description = "Whether the share is visible in network browse lists.";
          };

          guestOk = mkOption {
            type = types.bool;
            default = true;
            description = "Whether guests are allowed to access this specific share (requires guestAccess = true).";
          };

          validUsers = mkOption {
            type = types.listOf types.str;
            default = [cfg.adminUser];
            description = "List of users allowed to access the share. Set to [] to allow all authenticated users.";
          };

          forceUser = mkOption {
            type = types.nullOr types.str;
            default = cfg.adminUser;
            description = "Force created/modified files to be owned by this user (set to null to disable).";
          };

          forceGroup = mkOption {
            type = types.nullOr types.str;
            default = "users";
            description = "Force created/modified files to be owned by this group (set to null to disable).";
          };

          comment = mkOption {
            type = types.str;
            default = name;
            description = "Comment / description for the share.";
          };

          extraConfig = mkOption {
            type = types.attrsOf types.str;
            default = {};
            description = "Additional key-value settings for this share.";
          };
        };
      }));
      default = {
        data = {
          path = "/data";
          comment = "Zentraler Datenspeicher";
          readOnly = false;
          guestOk = true;
          forceUser = cfg.adminUser;
          forceGroup = "users";
        };
      };
      description = "Declarative specification of Samba shares.";
    };
  };

  config = mkIf (cfg.enable && cfg.samba.enable) {
    # Ensure shared directories exist with proper ownership and permissions
    systemd.tmpfiles.rules =
      lib.mapAttrsToList (
        _name: share: "d ${share.path} 0775 ${
          if share.forceUser != null
          then share.forceUser
          else "root"
        } ${
          if share.forceGroup != null
          then share.forceGroup
          else "users"
        } -"
      )
      cfg.samba.shares;

    # Install cifs-utils for mounting and troubleshooting
    environment.systemPackages = [pkgs.cifs-utils];

    # Samba Server
    services.samba = {
      enable = true;
      openFirewall = cfg.samba.openFirewall;

      settings =
        {
          global = {
            workgroup = "WORKGROUP";
            "server string" = "${config.networking.hostName} Samba Server";
            "netbios name" = config.networking.hostName;
            security = "user";
            "server min protocol" = "SMB2_10";
            "map to guest" =
              if cfg.samba.guestAccess
              then "bad user"
              else "never";
            "guest account" = "nobody";

            # macOS and modern client enhancements
            "ea support" = "yes";
            "vfs objects" = "acl_xattr catia fruit streams_xattr";
            "fruit:metadata" = "stream";
            "fruit:model" = "MacSamba";
            "fruit:posix_rename" = "yes";
            "fruit:veto_appledouble" = "no";
            "fruit:wipe_intentionally_left_blank_rfork" = "yes";
            "fruit:delete_empty_adfiles" = "yes";
          };
        }
        // (lib.mapAttrs shareToSamba cfg.samba.shares);
    };

    # Web Services Dynamic Discovery daemon for auto-discovery
    services.samba-wsdd = mkIf cfg.samba.wsdd {
      enable = true;
      openFirewall = cfg.samba.openFirewall;
      workgroup = "WORKGROUP";
      hostname = config.networking.hostName;
    };
  };
}
