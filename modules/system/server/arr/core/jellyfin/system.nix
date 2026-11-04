{
  config,
  lib,
  ...
}: let
  inherit (lib) mkIf;
  cfg = config.server.arr;
  sys = cfg.jellyfin.system;
  tp = sys.trickplay;
in {
  config = mkIf (cfg.enable && cfg.jellyfin.enable) {
    nixflix.jellyfin.system = {
      enableGroupingMoviesIntoCollections = sys.enableGroupingMoviesIntoCollections;
      trickplayOptions = {
        enableHwAcceleration = cfg.jellyfin.hardwareAcceleration != "none";
        enableHwEncoding = cfg.jellyfin.hardwareAcceleration != "none";
        processThreads = tp.processThreads;
        processPriority = tp.processPriority;
        scanBehavior = tp.scanBehavior;
        interval = tp.interval;
        widthResolutions = tp.widthResolutions;
        tileWidth = tp.tileWidth;
        tileHeight = tp.tileHeight;
        qscale = tp.qscale;
        jpegQuality = tp.jpegQuality;
      };
    };
  };
}
