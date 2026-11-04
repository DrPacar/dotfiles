{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (lib) mkOption mkIf mkForce optional optionals types;
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

      # Both 1080p, 4K, German, and Anime quality profiles are synced into Radarr and Sonarr so
      # both language and resolution tiers are available in their respective UIs and in Jellyseerr.
      # The active request profile defaults are configured in seerr.nix.
      config = {
        radarr.radarr = mkIf cfg.radarr.enable {
          quality_definition.type = "movie";

          quality_profiles = mkForce [
            {
              name = "Full HD (1080p) – Deutsch";
              trash_id = "2b90e905c99490edc7c7a5787443748b"; # [German] HD Bluray + WEB
              reset_unmatched_scores.enabled = true;
              min_format_score = 10000;
            }
            {
              name = "Full HD (1080p) – Englisch";
              trash_id = "0896c29d74de619df168d23b98104b22"; # [SQP] SQP-1 (1080p)
              reset_unmatched_scores.enabled = true;
              min_format_score = 180;
            }
            {
              name = "4K (2160p) – Deutsch";
              trash_id = "27cc3d153c0a799fd139ef1ff4c4cc42"; # [German] UHD Bluray + WEB
              reset_unmatched_scores.enabled = true;
              min_format_score = 10000;
            }
            {
              name = "4K (2160p) – Englisch";
              trash_id = "5128baeb2b081b72126bc8482b2a86a0"; # [SQP] SQP-1 (2160p)
              reset_unmatched_scores.enabled = true;
              min_format_score = 180;
            }
          ];

          custom_formats = [
            {
              trash_ids = [
                "923b6abef9b17f937fab56cfcf89e1f1" # DV (w/o HDR fallback)
              ];
              assign_scores_to = [
                {
                  name = "4K (2160p) – Deutsch";
                  score = -10000;
                }
              ];
            }
          ];
        };

        sonarr.sonarr = mkIf cfg.sonarr.enable {
          quality_profiles = mkForce (
            [
              {
                name = "Full HD (1080p) – Deutsch";
                trash_id = "dca7e5e9e99c703bcbdaaa471dd40e98"; # [German] HD Bluray + WEB
                reset_unmatched_scores.enabled = true;
              }
              {
                name = "Full HD (1080p) – Englisch";
                trash_id = "9d142234e45d6143785ac55f5a9e8dc9"; # WEB-1080p (Alternative)
                reset_unmatched_scores.enabled = true;
              }
              {
                name = "4K (2160p) – Deutsch";
                trash_id = "3b0fa37fddaaefc931b75f2889d4b4f5"; # [German] UHD Bluray + WEB
                reset_unmatched_scores.enabled = true;
              }
              {
                name = "4K (2160p) – Englisch";
                trash_id = "dfa5eaae7894077ad6449169b6eb03e0"; # WEB-2160p (Alternative)
                reset_unmatched_scores.enabled = true;
              }
            ]
            ++ optionals (!cfg.sonarr.anime.enable) [
              {
                name = "Anime (1080p) – Japanisch (Sub)";
                trash_id = "20e0fc959f1f1704bed501f23bdae76f"; # [Anime] Remux-1080p
                reset_unmatched_scores.enabled = true;
              }
              {
                name = "Anime (1080p) – Deutsch (Dub)";
                trash_id = "6fe5937e1dcc2269e23b49eb46dfe6d6"; # [German] Anime HD Bluray + WEB
                reset_unmatched_scores.enabled = true;
              }
              {
                name = "Anime (1080p) – Englisch (Dub)";
                trash_id = "20e0fc959f1f1704bed501f23bdae76f"; # [Anime] Remux-1080p
                reset_unmatched_scores.enabled = true;
              }
            ]
          );

          custom_formats = optionals (!cfg.sonarr.anime.enable) [
            {
              trash_ids = [
                "418f50b10f1907201b6cfdf881f467b7" # Anime Dual Audio
                "9c14d194486c4014d422adc64092d794" # Dubs Only
              ];
              assign_scores_to = [
                {
                  name = "Anime (1080p) – Englisch (Dub)";
                  score = 10000;
                }
              ];
            }
          ];
        };

        sonarr.sonarr_anime = mkIf (cfg.sonarr.enable && cfg.sonarr.anime.enable) {
          quality_profiles = mkForce [
            {
              name = "Anime (1080p) – Japanisch (Sub)";
              trash_id = "20e0fc959f1f1704bed501f23bdae76f"; # [Anime] Remux-1080p
              reset_unmatched_scores.enabled = true;
            }
            {
              name = "Anime (1080p) – Deutsch (Dub)";
              trash_id = "6fe5937e1dcc2269e23b49eb46dfe6d6"; # [German] Anime HD Bluray + WEB
              reset_unmatched_scores.enabled = true;
            }
            {
              name = "Anime (1080p) – Englisch (Dub)";
              trash_id = "20e0fc959f1f1704bed501f23bdae76f"; # [Anime] Remux-1080p
              reset_unmatched_scores.enabled = true;
            }
          ];

          custom_formats = [
            {
              trash_ids = [
                "418f50b10f1907201b6cfdf881f467b7" # Anime Dual Audio
                "9c14d194486c4014d422adc64092d794" # Dubs Only
              ];
              assign_scores_to = [
                {
                  name = "Anime (1080p) – Englisch (Dub)";
                  score = 10000;
                }
              ];
            }
          ];
        };
      };

      # Automatically clean up old, unmanaged quality profiles (Any, SD, 720p, etc.)
      # to keep the Jellyseerr dropdown clean and clutter-free.
      cleanupUnmanagedProfiles = {
        enable = true;
        managedProfiles = [
          "Full HD (1080p) – Deutsch"
          "Full HD (1080p) – Englisch"
          "4K (2160p) – Deutsch"
          "4K (2160p) – Englisch"
          "Anime (1080p) – Japanisch (Sub)"
          "Anime (1080p) – Deutsch (Dub)"
          "Anime (1080p) – Englisch (Dub)"
        ];
      };
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
