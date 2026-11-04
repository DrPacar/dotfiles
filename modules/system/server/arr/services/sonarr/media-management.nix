{
  config,
  lib,
  ...
}: let
  inherit (lib) mkIf mkMerge;
  cfg = config.server.arr;

  commonMediaManagement = {
    setPermissionsLinux = true;
    chmodFolder = "775";
    chownGroup = cfg.mediaGroup;
    importExtraFiles = true;
    extraFileExtensions = "srt";
    copyUsingHardlinks = true;
    deleteEmptyFolders = true;
    rescanAfterRefresh = "always";
    downloadPropersAndRepacks = "preferAndUpgrade";
    autoUnmonitorPreviouslyDownloadedEpisodes = false;
    createEmptySeriesFolders = false;
    episodeTitleRequired = "always";
    fileDate = cfg.sonarr.fileDate;
  };
in {
  config = mkIf (cfg.enable && cfg.sonarr.enable) (mkMerge [
    {
      nixflix.sonarr.config.mediaManagement = commonMediaManagement;
    }
    (mkIf cfg.sonarr.anime.enable {
      nixflix.sonarr-anime.config.mediaManagement = commonMediaManagement;
    })
  ]);
}
