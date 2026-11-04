{
  config,
  lib,
  ...
}: let
  inherit (lib) mkIf;
  cfg = config.server.arr;
in {
  config = mkIf (cfg.enable && cfg.radarr.enable) {
    nixflix.radarr.config.mediaManagement = {
      setPermissionsLinux = true;
      chmodFolder = "775";
      chownGroup = cfg.mediaGroup;
      importExtraFiles = true;
      extraFileExtensions = "srt";
      copyUsingHardlinks = true;
      deleteEmptyFolders = true;
      rescanAfterRefresh = "always";
      downloadPropersAndRepacks = "preferAndUpgrade";
      autoUnmonitorPreviouslyDownloadedMovies = false;
      fileDate = cfg.radarr.fileDate;
    };
  };
}
