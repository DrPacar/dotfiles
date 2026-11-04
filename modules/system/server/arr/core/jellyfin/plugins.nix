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

    # Dynamic synchronization of OpenSubtitles credentials via API at runtime
    # to avoid leaking passwords in cleartext in /nix/store
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
      };

      path = with pkgs; [curl jq coreutils];

      script = ''
        TOKEN=$(cat ${config.sops.secrets.arr_jellyfin_api_key.path} | tr -d '\n\r')
        USER=$(cat ${config.sops.secrets.arr_opensubtitles_username.path} | tr -d '\n\r')
        PASS=$(cat ${config.sops.secrets.arr_opensubtitles_password.path} | tr -d '\n\r')
        URL="http://${cfg.network.localAddress}:${toString cfg.jellyfin.port}"

        # Wait up to 30 seconds for Jellyfin API to be responsive
        for i in $(seq 1 15); do
          if curl -s -f -H "X-Emby-Token: $TOKEN" "$URL/System/Info" >/dev/null 2>&1; then
            break
          fi
          sleep 2
        done

        PLUGIN_ID=$(curl -s -H "X-Emby-Token: $TOKEN" "$URL/Plugins" | jq -r '.[] | select(.Name == "Open Subtitles") | .Id')
        if [ -n "$PLUGIN_ID" ] && [ "$PLUGIN_ID" != "null" ]; then
          PAYLOAD=$(jq -n --arg user "$USER" --arg pass "$PASS" '{"Username": $user, "Password": $pass}')
          curl -s -f -X POST \
            -H "X-Emby-Token: $TOKEN" \
            -H "Content-Type: application/json" \
            -d "$PAYLOAD" \
            "$URL/Plugins/$PLUGIN_ID/Configuration" >/dev/null
          echo "OpenSubtitles credentials synchronized to Jellyfin successfully."
        else
          echo "Open Subtitles plugin not found in Jellyfin."
        fi
      '';
    };
  };
}
