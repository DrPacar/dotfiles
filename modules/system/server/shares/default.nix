{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (lib) attrNames elem filter hasPrefix listToAttrs mapAttrsToList mkIf optionals optionalAttrs unique;
  cfg = config.networking.shares;
  shares = import ./_lib.nix {inherit config lib;};

  mkCifsOptions = entry: let
    sambaSameHost =
      (config.services.samba.enable or false)
      && entry.host != null
      && (config.networking.hostName == entry.host || elem entry.host ["127.0.0.1" "localhost" "::1"]);
  in
    [
      # 1. On-demand automount: never blocks boot when offline or remote
      "x-systemd.automount"
      "noauto"
      "x-systemd.mount-timeout=${toString entry.mountTimeout}"
      "_netdev"
      # 2. Modern SMB dialect, UTF-8, and non-blocking I/O on disconnect
      "vers=${entry.smbVersion}"
      "iocharset=utf8"
      # 3. Local user/group ownership and permissions
      "uid=${shares.resolveUid entry}"
      "gid=${shares.resolveGid entry}"
      "file_mode=${entry.fileMode}"
      "dir_mode=${entry.dirMode}"
      (
        if entry.readOnly
        then "ro"
        else "rw"
      )
      # 4. Authentication
      (
        if entry.credentialsFile != null
        then "credentials=${entry.credentialsFile}"
        else "guest"
      )
    ]
    ++ lib.optional (entry.idleTimeout > 0) "x-systemd.idle-timeout=${toString entry.idleTimeout}"
    ++ lib.optional entry.softMount "soft"
    ++ lib.optional sambaSameHost "x-systemd.after=samba-smbd.service"
    ++ entry.extraOptions;

  remoteFileSystems =
    lib.mapAttrs' (
      _name: entry:
        lib.nameValuePair entry.mountPoint {
          device = "//${entry.host}/${entry.shareName}";
          fsType = "cifs";
          options = mkCifsOptions entry;
        }
    )
    shares.remoteEntries;

  mountPointRules =
    mapAttrsToList (
      _name: entry: "d ${entry.mountPoint} 0755 root root -"
    )
    shares.remoteEntries;

  symlinkParentRules = unique (
    lib.concatMap (
      entry: let
        linkPath = shares.resolveSymlinkPath entry;
        parentDir =
          if linkPath != null
          then dirOf linkPath
          else null;
        userHome = shares.resolveUserHome entry;
        groupName = shares.resolveGroupName entry;
      in
        lib.optional (linkPath != null && parentDir != userHome && parentDir != "/")
        "d ${parentDir} 0755 ${entry.user} ${groupName} -"
    )
    (lib.attrValues shares.enabledEntries)
  );

  symlinkRules =
    lib.concatMap (
      entry: let
        linkPath = shares.resolveSymlinkPath entry;
        targetPath = shares.resolveTargetPath entry;
      in
        lib.optional (linkPath != null) "L+ ${linkPath} - - - - ${targetPath}"
    )
    (lib.attrValues shares.enabledEntries);

  remoteMountPoints = mapAttrsToList (_: e: e.mountPoint) shares.remoteEntries;
  symlinkPaths = lib.filter (p: p != null) (mapAttrsToList (_: shares.resolveSymlinkPath) shares.enabledEntries);

  entryAssertions = lib.concatLists (
    mapAttrsToList (
      name: entry: let
        local = shares.isLocalEntry entry;
      in [
        {
          assertion = local || (entry.host != null && entry.host != "");
          message = "networking.shares.entries.${name}: 'host' must be set unless 'isLocal = true' (or host matches networking.hostName with localPath set).";
        }
        {
          assertion = !local || (entry.localPath != null && entry.localPath != "" && hasPrefix "/" entry.localPath);
          message = "networking.shares.entries.${name}: 'localPath' must be an absolute path when local mode is active.";
        }
        {
          assertion = hasPrefix "/" entry.mountPoint;
          message = "networking.shares.entries.${name}: 'mountPoint' must be an absolute path.";
        }
        {
          assertion = entry.credentialsFile == null || !(hasPrefix builtins.storeDir entry.credentialsFile);
          message = "networking.shares.entries.${name}: 'credentialsFile' must not point to a path inside the Nix store (secrets would be world-readable).";
        }
        {
          assertion = config.users.users ? ${entry.user};
          message = "networking.shares.entries.${name}: user '${entry.user}' is not defined in config.users.users.";
        }
        {
          assertion = entry.group == null || (config.users.groups ? ${entry.group});
          message = "networking.shares.entries.${name}: group '${toString entry.group}' is not defined in config.users.groups.";
        }
        {
          assertion = !entry.symlink.enable || (hasPrefix "/" (shares.resolveSymlinkPath entry));
          message = "networking.shares.entries.${name}: 'symlink.path' must be an absolute path.";
        }
      ]
    )
    shares.enabledEntries
  );
in {
  config = mkIf cfg.enable {
    assertions =
      entryAssertions
      ++ [
        {
          assertion = builtins.length remoteMountPoints == builtins.length (unique remoteMountPoints);
          message = "networking.shares: duplicate mountPoint configured across enabled remote share entries.";
        }
        {
          assertion = builtins.length symlinkPaths == builtins.length (unique symlinkPaths);
          message = "networking.shares: duplicate symlink.path configured across enabled share entries.";
        }
      ];

    # Install cifs-utils only when remote CIFS mounts are actually configured
    environment.systemPackages = lib.mkIf (shares.remoteEntries != {}) [pkgs.cifs-utils];

    fileSystems = remoteFileSystems;

    systemd.tmpfiles.rules = mountPointRules ++ symlinkParentRules ++ symlinkRules;
  };
}
