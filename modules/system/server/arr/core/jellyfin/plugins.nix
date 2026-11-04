{
  config,
  pkgs,
  lib,
  ...
}: let
  inherit (lib) mkIf;
  cfg = config.server.arr;
  jellyfinUser = "jellyfin";
in {
  config = mkIf (cfg.enable && cfg.jellyfin.enable) {
    nixflix.jellyfin.plugins = {
      "Intro Skipper".enable = cfg.jellyfin.introSkipper.enable;
      "Playback Reporting".enable = cfg.jellyfin.plugins.playbackReporting;
      "Open Subtitles".enable = cfg.jellyfin.plugins.openSubtitles;
      "TMDb Box Sets".enable = cfg.jellyfin.plugins.tmdbBoxSets;
      "AniDB".enable = cfg.jellyfin.plugins.animeMetadata;
      "AniList".enable = cfg.jellyfin.plugins.animeMetadata;
    };

    systemd.services.jellyfin-opensubtitles-sync = mkIf cfg.jellyfin.plugins.openSubtitles {
      description = "Synchronize OpenSubtitles credentials to Jellyfin plugin";
      after = ["jellyfin.service" "jellyfin-plugins.service"];
      wants = ["jellyfin.service"];
      wantedBy = ["multi-user.target"];

      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        User = jellyfinUser;
        Group = cfg.mediaGroup;
        ExecStart = [
          "${pkgs.bash}/bin/bash ${./scripts/sync-opensubtitles.sh} --url http://${cfg.network.localAddress}:${toString cfg.jellyfin.port} --token-file ${config.sops.secrets.arr_jellyfin_api_key.path} --user-file ${config.sops.secrets.arr_opensubtitles_username.path} --pass-file ${config.sops.secrets.arr_opensubtitles_password.path}"
        ];
      };

      path = with pkgs; [curl jq coreutils];
    };
  };
}
