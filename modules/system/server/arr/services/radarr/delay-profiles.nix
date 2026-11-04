{
  config,
  lib,
  ...
}: let
  inherit (lib) mkIf;
  cfg = config.server.arr;
in {
  config = mkIf (cfg.enable && cfg.radarr.enable) {
    nixflix.radarr.config.delayProfiles = [
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
  };
}
