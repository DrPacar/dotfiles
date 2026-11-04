{
  config,
  lib,
  ...
}: let
  inherit (lib) mkIf mkDefault mapAttrs;
  cfg = config.server.arr;
  inherit (import ../../_lib.nix) secretRef;
in {
  config = mkIf (cfg.enable && cfg.jellyfin.enable) {
    # Ensure default admin user is configured declaratively
    server.arr.jellyfin.users = {
      ${cfg.jellyfin.adminUser} = {
        isAdmin = true;
        passwordSecret = config.sops.secrets.arr_jellyfin_admin_password.path;
        mutable = mkDefault false;
        displayCollectionsView = true;
        audioLanguage = "ger";
        subtitleLanguage = "ger";
        subtitleMode = "OnlyForced";
        rememberAudioSelections = true;
        rememberSubtitleSelections = true;
        enableNextEpisodeAutoPlay = true;
      };
    };

    # Transform server.arr.jellyfin.users into nixflix.jellyfin.users
    nixflix.jellyfin.users =
      mapAttrs (_name: u: {
        policy = {
          isAdministrator = u.isAdmin;
          enableCollectionManagement = u.isAdmin;
          enableContentDeletion = u.enableContentDeletion;
          enableMediaPlayback = u.enableMediaPlayback;
          enableAudioPlaybackTranscoding = u.enableAudioPlaybackTranscoding;
          enableVideoPlaybackTranscoding = u.enableVideoPlaybackTranscoding;
          enablePlaybackRemuxing = u.enablePlaybackRemuxing;
          enableContentDownloading = u.enableContentDownloading;
          enableAllFolders = true;
          enableAllDevices = true;
        };
        password = mkIf (u.passwordSecret != null) (secretRef u.passwordSecret);
        mutable = u.mutable;
        configuration = {
          displayCollectionsView = u.displayCollectionsView;
          audioLanguagePreference = u.audioLanguage;
          playDefaultAudioTrack = false;
          subtitleLanguagePreference = u.subtitleLanguage;
          subtitleMode = u.subtitleMode;
          rememberAudioSelections = u.rememberAudioSelections;
          rememberSubtitleSelections = u.rememberSubtitleSelections;
          enableNextEpisodeAutoPlay = u.enableNextEpisodeAutoPlay;
        };
      })
      cfg.jellyfin.users;
  };
}
