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
  config = mkIf (cfg.enable && cfg.sonarr.enable) {
    nixflix.sonarr.config.delayProfiles = commonDelayProfiles;
  };
}
