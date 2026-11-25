# Shared helpers, pre-backup database snapshot builder, and alert dispatch for backup.
# Prefixed with '_' so lib/mod.nix does not auto-import this helper directly as a NixOS module.
{
  config,
  lib,
  pkgs,
}: let
  cfg = config.backup;
  inherit (import ../server/_lib.nix) mkNotifyBin;

  sqliteDumpDir = "/var/backup/sqlite";

  postgresActive =
    cfg.client.databases.postgresql.enable
    && (config.services.postgresql.enable or false);

  sqliteActive = cfg.client.databases.sqlite != [];

  effectivePaths =
    cfg.client.paths
    ++ lib.optional postgresActive cfg.client.databases.postgresql.dumpDir
    ++ lib.optional sqliteActive sqliteDumpDir;

  prepareScript = let
    pgDumpDir = cfg.client.databases.postgresql.dumpDir;
    pgPkg = config.services.postgresql.package or pkgs.postgresql;
    sqliteCmds =
      lib.concatMapStringsSep "\n" (db: ''
        if [ -f ${lib.escapeShellArg db.path} ]; then
          rm -f ${lib.escapeShellArg "${sqliteDumpDir}/${db.destName}.tmp"}
          ${pkgs.sqlite}/bin/sqlite3 ${lib.escapeShellArg db.path} ".backup '${sqliteDumpDir}/${db.destName}.tmp'"
          mv -f ${lib.escapeShellArg "${sqliteDumpDir}/${db.destName}.tmp"} ${lib.escapeShellArg "${sqliteDumpDir}/${db.destName}"}
          chmod 600 ${lib.escapeShellArg "${sqliteDumpDir}/${db.destName}"}
        else
          echo "WARN: [backup-prepare] SQLite database '${db.path}' not found; skipping." >&2
        fi
      '')
      cfg.client.databases.sqlite;
  in
    if (!postgresActive && !sqliteActive && cfg.client.backupPrepareCommand == null)
    then null
    else
      pkgs.writeShellScript "restic-prepare" ''
        set -euo pipefail
        ${lib.optionalString postgresActive ''
          install -d -m 0700 -o root -g root ${lib.escapeShellArg pgDumpDir}
          ${pkgs.util-linux}/bin/runuser -u postgres -- ${pgPkg}/bin/pg_dumpall --clean --if-exists \
            > ${lib.escapeShellArg "${pgDumpDir}/all.sql.tmp"}
          chmod 600 ${lib.escapeShellArg "${pgDumpDir}/all.sql.tmp"}
          mv -f ${lib.escapeShellArg "${pgDumpDir}/all.sql.tmp"} ${lib.escapeShellArg "${pgDumpDir}/all.sql"}
        ''}
        ${lib.optionalString sqliteActive ''
          install -d -m 0700 -o root -g root ${lib.escapeShellArg sqliteDumpDir}
          ${sqliteCmds}
        ''}
        ${lib.optionalString (cfg.client.backupPrepareCommand != null) cfg.client.backupPrepareCommand}
      '';

  notifyBin = mkNotifyBin {
    inherit pkgs lib config;
    inherit (cfg.notifications) enable handler;
    name = "backup-notify";
    title = "Backup (${config.networking.hostName})";
  };
in {
  inherit
    sqliteDumpDir
    postgresActive
    sqliteActive
    effectivePaths
    prepareScript
    notifyBin
    ;
}
