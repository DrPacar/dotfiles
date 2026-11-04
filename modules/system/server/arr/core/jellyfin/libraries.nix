{
  config,
  lib,
  ...
}: let
  inherit (lib) mkIf mapAttrs;
  cfg = config.server.arr;
  libCfg = cfg.jellyfin.libraries;

  commonLibSettings = {
    enableRealtimeMonitor = cfg.jellyfin.realtimeMonitor;
    saveLocalMetadata = libCfg.saveLocalMetadata;
    enablePhotos = libCfg.enablePhotos;
    enableLUFSScan = libCfg.enableLUFSScan;
    enableChapterImageExtraction = libCfg.enableChapterImageExtraction;
    extractChapterImagesDuringLibraryScan = libCfg.extractChapterImagesDuringLibraryScan;
    enableTrickplayImageExtraction = libCfg.enableTrickplayImageExtraction;
    extractTrickplayImagesDuringLibraryScan = libCfg.extractTrickplayImagesDuringLibraryScan;
  };
in {
  config = mkIf (cfg.enable && cfg.jellyfin.enable) {
    nixflix.jellyfin.libraries =
      {
        Movies =
          commonLibSettings
          // {
            collectionType = "movies";
            paths = lib.mkForce [cfg.paths.movies];
            typeOptions = [
              {
                type = "Movie";
                imageFetchers = [
                  "TheMovieDb"
                  "The Open Movie Database"
                  "Embedded Image Extractor"
                  "Screen Grabber"
                ];
                imageFetcherOrder = [
                  "TheMovieDb"
                  "The Open Movie Database"
                  "Embedded Image Extractor"
                  "Screen Grabber"
                ];
                metadataFetchers = libCfg.moviesMetadataPriority;
                metadataFetcherOrder = libCfg.moviesMetadataPriority;
              }
            ];
          };

        Shows =
          commonLibSettings
          // {
            collectionType = "tvshows";
            paths = lib.mkForce [cfg.paths.tv];
            typeOptions = [
              {
                type = "Series";
                imageFetchers = ["TheMovieDb"];
                imageFetcherOrder = ["TheMovieDb"];
                metadataFetchers = libCfg.showsMetadataPriority;
                metadataFetcherOrder = libCfg.showsMetadataPriority;
              }
              {
                type = "Season";
                imageFetchers = ["TheMovieDb"];
                imageFetcherOrder = ["TheMovieDb"];
                metadataFetchers = libCfg.showsMetadataPriority;
                metadataFetcherOrder = libCfg.showsMetadataPriority;
              }
              {
                type = "Episode";
                imageFetchers = [
                  "TheMovieDb"
                  "The Open Movie Database"
                  "Embedded Image Extractor"
                  "Screen Grabber"
                ];
                imageFetcherOrder = [
                  "TheMovieDb"
                  "The Open Movie Database"
                  "Embedded Image Extractor"
                  "Screen Grabber"
                ];
                metadataFetchers = libCfg.showsMetadataPriority;
                metadataFetcherOrder = libCfg.showsMetadataPriority;
              }
            ];
          };

        Anime =
          commonLibSettings
          // {
            collectionType = "tvshows";
            paths = lib.mkForce [cfg.paths.anime];
            typeOptions = [
              {
                type = "Series";
                imageFetchers = [
                  "AniDB"
                  "AniSearch"
                  "TheMovieDb"
                ];
                imageFetcherOrder = [
                  "AniDB"
                  "AniSearch"
                  "TheMovieDb"
                ];
                metadataFetchers = libCfg.animeMetadataPriority;
                metadataFetcherOrder = libCfg.animeMetadataPriority;
              }
              {
                type = "Season";
                imageFetchers = [
                  "AniDB"
                  "AniSearch"
                  "TheMovieDb"
                ];
                imageFetcherOrder = [
                  "AniDB"
                  "AniSearch"
                  "TheMovieDb"
                ];
                metadataFetchers = libCfg.animeMetadataPriority;
                metadataFetcherOrder = libCfg.animeMetadataPriority;
              }
              {
                type = "Episode";
                imageFetchers = [
                  "TheMovieDb"
                  "The Open Movie Database"
                  "Embedded Image Extractor"
                  "Screen Grabber"
                ];
                imageFetcherOrder = [
                  "TheMovieDb"
                  "The Open Movie Database"
                  "Embedded Image Extractor"
                  "Screen Grabber"
                ];
                metadataFetchers = libCfg.animeMetadataPriority;
                metadataFetcherOrder = libCfg.animeMetadataPriority;
              }
            ];
          };
      }
      // (mapAttrs (_name: custom:
        commonLibSettings
        // {
          inherit (custom) collectionType paths enableRealtimeMonitor;
        })
      libCfg.custom);
  };
}
