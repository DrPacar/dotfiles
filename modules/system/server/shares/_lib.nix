# Shared constants, path resolution helpers, and runtime manifest for networking.shares.
# Prefixed with '_' so lib/mod.nix does not auto-import this helper directly as a NixOS module.
{
  config,
  lib,
}: let
  inherit (lib) attrNames elem filterAttrs head hasPrefix listToAttrs mapAttrs mapAttrsToList;
  cfg = config.networking.shares;

  enabledEntries = filterAttrs (_: entry: entry.enable) cfg.entries;

  isLocalEntry = entry:
    entry.isLocal
    || (
      entry.localPath
      != null
      && entry.host != null
      && config.networking.hostName == entry.host
    );

  remoteEntries = filterAttrs (_: entry: !(isLocalEntry entry)) enabledEntries;
  localEntries = filterAttrs (_: entry: isLocalEntry entry) enabledEntries;

  resolveUserAttr = entry: config.users.users.${entry.user} or {};

  resolveUid = entry: let
    userObj = resolveUserAttr entry;
    uid = userObj.uid or null;
  in
    if uid != null
    then toString uid
    else entry.user;

  resolveGroupName = entry: let
    userObj = resolveUserAttr entry;
  in
    if entry.group != null
    then entry.group
    else (userObj.group or "users");

  resolveGid = entry: let
    groupName = resolveGroupName entry;
    groupObj = config.users.groups.${groupName} or {};
    gid = groupObj.gid or null;
  in
    if gid != null
    then toString gid
    else groupName;

  resolveUserHome = entry: let
    userObj = resolveUserAttr entry;
  in
    userObj.home or "/home/${entry.user}";

  resolveTargetPath = entry:
    if isLocalEntry entry
    then entry.localPath
    else entry.mountPoint;

  resolveSymlinkPath = entry:
    if !entry.symlink.enable
    then null
    else if entry.symlink.path != null
    then entry.symlink.path
    else "${resolveUserHome entry}/${entry.shareName}";

  entryToManifest = name: entry: let
    local = isLocalEntry entry;
  in {
    inherit name;
    mode =
      if local
      then "local"
      else "cifs";
    inherit (entry) host shareName mountPoint localPath user smbVersion softMount idleTimeout mountTimeout readOnly;
    group = resolveGroupName entry;
    targetPath = resolveTargetPath entry;
    symlinkPath = resolveSymlinkPath entry;
    authMode =
      if local
      then "local"
      else if entry.credentialsFile != null
      then "credentials"
      else "guest";
  };

  manifestList = mapAttrsToList entryToManifest enabledEntries;
  manifestJson = builtins.toJSON manifestList;
in {
  inherit
    enabledEntries
    remoteEntries
    localEntries
    isLocalEntry
    resolveUid
    resolveGid
    resolveTargetPath
    resolveSymlinkPath
    manifestJson
    ;
}
