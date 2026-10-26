{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (lib) mkOption mkIf mkForce optional types;
  cfg = config.server.arr;
in {
  options.server.arr.recyclarr = {
    enable = mkOption {
      type = types.bool;
      default = true;
      description = "Enable Recyclarr automated TRaSH guides syncing.";
    };
  };

  config = mkIf (cfg.enable && cfg.recyclarr.enable && (cfg.radarr.enable || cfg.sonarr.enable)) {
    nixflix.recyclarr = {
      enable = true;

      # Both 1080p and 4K quality profiles are synced into Radarr and Sonarr so
      # both tiers are available in their respective UIs and in Jellyseerr.
      # The active request profile defaults (1080p) are configured in seerr.nix.
      config = {
        radarr.radarr = mkIf cfg.radarr.enable {
          quality_profiles = mkForce [
            {
              trash_id = "0896c29d74de619df168d23b98104b22"; # [SQP] SQP-1 (1080p)
              reset_unmatched_scores.enabled = true;
              min_format_score = 180;
            }
            {
              trash_id = "5128baeb2b081b72126bc8482b2a86a0"; # [SQP] SQP-1 (2160p)
              reset_unmatched_scores.enabled = true;
              min_format_score = 180;
            }
          ];
        };

        sonarr.sonarr = mkIf cfg.sonarr.enable {
          quality_profiles = mkForce [
            {
              trash_id = "9d142234e45d6143785ac55f5a9e8dc9"; # WEB-1080p (Alternative)
              reset_unmatched_scores.enabled = true;
            }
            {
              trash_id = "dfa5eaae7894077ad6449169b6eb03e0"; # WEB-2160p (Alternative)
              reset_unmatched_scores.enabled = true;
            }
          ];
        };
      };

      # Ensure both 1080p, 4K, and anime profiles are protected if profile cleanup is ever enabled
      cleanupUnmanagedProfiles.managedProfiles =
        [
          "[SQP] SQP-1 (1080p)"
          "[SQP] SQP-1 (2160p)"
          "WEB-1080p (Alternative)"
          "WEB-2160p (Alternative)"
        ]
        ++ optional cfg.sonarr.anime.enable "[Anime] Remux-1080p";
    };

    # Automatically wait for network & DNS at boot, preventing failures when Wi-Fi connects after systemd startup
    systemd.services.recyclarr = {
      after =
        ["network-online.target"]
        ++ lib.optional cfg.sonarr.enable "sonarr.service"
        ++ lib.optional (cfg.sonarr.enable && cfg.sonarr.anime.enable) "sonarr-anime.service"
        ++ lib.optional cfg.radarr.enable "radarr.service";
      wants =
        lib.optional cfg.sonarr.enable "sonarr.service"
        ++ lib.optional (cfg.sonarr.enable && cfg.sonarr.anime.enable) "sonarr-anime.service"
        ++ lib.optional cfg.radarr.enable "radarr.service";

      path = with pkgs; [
        bash
        curl
        coreutils
      ];

      serviceConfig = {
        ExecStartPre = lib.mkBefore [
          "${pkgs.bash}/bin/bash ${../scripts/wait-for-internet.sh} --service-name recyclarr --url https://github.com --timeout 60"
        ];
        Restart = "on-failure";
        RestartSec = 15;
      };
      unitConfig = {
        StartLimitIntervalSec = 300;
        StartLimitBurst = 5;
      };
    };
  };
}
