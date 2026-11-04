{
  config,
  lib,
  ...
}: let
  inherit (lib) mkIf mkDefault mkForce optionalAttrs;
  cfg = config.server.arr;
in {
  config = mkIf cfg.enable {
    # -------------------------------------------------------------------------
    # Shared Permissions & Storage Structure
    # -------------------------------------------------------------------------
    users.groups.${cfg.mediaGroup} =
      {
        members = [cfg.mediaUser] ++ lib.optional cfg.bazarr.enable "bazarr";
      }
      // lib.optionalAttrs (cfg.mediaGid != null) {
        gid = mkDefault cfg.mediaGid;
      };

    # Configure directory hierarchy with setgid (2775)
    # Using systemd.tmpfiles.settings."10-nixflix" directly to avoid conflicting duplicate tmpfiles rules
    systemd.tmpfiles.settings."10-nixflix" =
      {
        "${cfg.dataDir}".d = {
          mode = "2775";
          user = "root";
          group = cfg.mediaGroup;
        };
        "${cfg.paths.torrents}".d = {
          mode = mkForce "2775";
          user = "root";
          group = cfg.mediaGroup;
        };
        "${cfg.paths.torrents}/default".d = {
          mode = "2775";
          user = "root";
          group = cfg.mediaGroup;
        };
        "${cfg.paths.media}".d = {
          mode = mkForce "2775";
          user = "root";
          group = cfg.mediaGroup;
        };
      }
      // optionalAttrs cfg.radarr.enable {
        "${cfg.paths.torrents}/radarr".d = {
          mode = "2775";
          user = "root";
          group = cfg.mediaGroup;
        };
        "${cfg.paths.movies}".d = {
          mode = "2775";
          user = "root";
          group = cfg.mediaGroup;
        };
      }
      // optionalAttrs cfg.sonarr.enable {
        "${cfg.paths.torrents}/sonarr".d = {
          mode = "2775";
          user = "root";
          group = cfg.mediaGroup;
        };
        "${cfg.paths.tv}".d = {
          mode = "2775";
          user = "root";
          group = cfg.mediaGroup;
        };
      }
      // optionalAttrs (cfg.sonarr.enable && cfg.sonarr.anime.enable) {
        "${cfg.paths.torrents}/sonarr-anime".d = {
          mode = "2775";
          user = "root";
          group = cfg.mediaGroup;
        };
        "${cfg.paths.anime}".d = {
          mode = "2775";
          user = "root";
          group = cfg.mediaGroup;
        };
      };
  };
}
