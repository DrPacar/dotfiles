{
  config,
  lib,
  ...
}: let
  inherit (lib) mkIf mkMerge;
  cfg = config.server.arr;

  commonDelayProfiles = [
    {
      id = 1;
      enableUsenet = false;
      enableTorrent = true;
      preferredProtocol = "torrent";
      torrentDelay = 0;
      bypassIfHighestQuality = true;
      order = 1;
    }
  ];
in {
  config = mkIf (cfg.enable && cfg.sonarr.enable) (mkMerge [
    {
      nixflix.sonarr.config.delayProfiles = commonDelayProfiles;
    }
    (mkIf cfg.sonarr.anime.enable {
      nixflix.sonarr-anime.config.delayProfiles = commonDelayProfiles;
    })
  ]);
}
