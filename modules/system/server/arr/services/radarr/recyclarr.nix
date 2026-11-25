{
  config,
  lib,
  ...
}: let
  inherit (lib) mkIf mkForce;
  cfg = config.server.arr;

  englishProfiles = [
    "Full HD (1080p) – Englisch"
    "4K (2160p) – Englisch"
  ];
  assignScore = score: profiles:
    map (name: {
      inherit name score;
    })
    profiles;
in {
  config = mkIf (cfg.enable && cfg.recyclarr.enable && cfg.radarr.enable) {
    nixflix.recyclarr.config.radarr.radarr = {
      # Tuned for crisp TV Direct Play and smooth remote Fire TV streaming over Tailscale
      quality_definition = {
        type = "movie";
        qualities = [
          {
            name = "Bluray-2160p";
            min = 50;
            preferred = 180;
            max = 350;
          }
          {
            name = "WEBDL-2160p";
            min = 35;
            preferred = 140;
            max = 280;
          }
          {
            name = "WEBRip-2160p";
            min = 35;
            preferred = 140;
            max = 280;
          }
          {
            name = "Bluray-1080p";
            min = 10;
            preferred = 95;
            max = 220;
          }
          {
            name = "WEBDL-1080p";
            min = 10;
            preferred = 65;
            max = 150;
          }
          {
            name = "WEBRip-1080p";
            min = 10;
            preferred = 65;
            max = 150;
          }
          {
            name = "Bluray-720p";
            min = 12;
            preferred = 45;
            max = 100;
          }
          {
            name = "WEBDL-720p";
            min = 10;
            preferred = 35;
            max = 80;
          }
          {
            name = "WEBRip-720p";
            min = 10;
            preferred = 35;
            max = 80;
          }
        ];
      };

      quality_profiles = mkForce [
        {
          name = "Full HD (1080p) – Deutsch";
          trash_id = "2b90e905c99490edc7c7a5787443748b"; # [German] HD Bluray + WEB
          reset_unmatched_scores.enabled = true;
          min_format_score = 10000;
        }
        {
          name = "Full HD (1080p) – Englisch";
          trash_id = "d1d67249d3890e49bc12e275d989a7e9"; # HD Bluray + WEB
          reset_unmatched_scores.enabled = true;
          min_format_score = -500;
          upgrade = {
            allowed = true;
            until_quality = "Bluray|WEB-1080p";
            until_score = 10000;
          };
          qualities = [
            {
              name = "Bluray|WEB-1080p";
              qualities = [
                "Bluray-1080p"
                "WEBRip-1080p"
                "WEBDL-1080p"
              ];
            }
            {name = "Bluray-720p";}
            {
              name = "WEB 720p";
              qualities = [
                "WEBRip-720p"
                "WEBDL-720p"
              ];
            }
          ];
        }
        {
          name = "4K (2160p) – Deutsch";
          trash_id = "27cc3d153c0a799fd139ef1ff4c4cc42"; # [German] UHD Bluray + WEB
          reset_unmatched_scores.enabled = true;
          min_format_score = 10000;
        }
        {
          name = "4K (2160p) – Englisch";
          trash_id = "64fb5f9858489bdac2af690e27c8f42f"; # UHD Bluray + WEB
          reset_unmatched_scores.enabled = true;
          min_format_score = -500;
        }
      ];

      custom_formats = [
        # Hardware-accelerated HEVC (UHD 630 + Fire TV) saves streaming bandwidth
        {
          trash_ids = [
            "dc98083864ea246d05a42df0d05f81cc" # x265 (HD)
          ];
          assign_scores_to = assignScore 0 [
            "Full HD (1080p) – Englisch"
            "Full HD (1080p) – Deutsch"
          ];
        }

        # Block formats that break TV playback or force software decoding on Coffee Lake UHD 630
        {
          trash_ids = [
            "923b6abef9b17f937fab56cfcf89e1f1" # DV (w/o HDR fallback) - causes wrong colors on non-DV TVs
          ];
          assign_scores_to = assignScore (-10000) (englishProfiles ++ ["4K (2160p) – Deutsch"]);
        }
        {
          trash_ids = [
            "cae4ca30163749b891686f95532519bd" # AV1 (no hardware decode on Coffee Lake UHD 630)
            "b8cd450cbfa689c0259a01d9e29ba3d6" # 3D
            "ed38b889b31be83fda192888e2286d83" # BR-DISK
            "c465ccc73923871b3eb1802042331306" # Line/Mic Dubbed
            "bfd8eb01832d646a0a89c4deb46f8564" # Upscaled
            "0a3f082873eb454bde444150b70253cc" # Extras
            "712d74cd88bceb883ee32f773656b1f5" # Sing-Along Versions
          ];
          assign_scores_to = assignScore (-10000) englishProfiles;
        }

        # Prefer Fire TV / TV Direct-Play audio codecs (no transcoding needed)
        {
          trash_ids = ["1af239278386be2919e1bcee0bde047e"]; # DD+ ATMOS
          assign_scores_to = assignScore 250 englishProfiles;
        }
        {
          trash_ids = ["185f1dd7264c4562b9022d963ac37424"]; # DD+
          assign_scores_to = assignScore 200 englishProfiles;
        }
        {
          trash_ids = ["c2998bd0d90ed5621d8df281e839436e"]; # DD
          assign_scores_to = assignScore 150 englishProfiles;
        }
        {
          trash_ids = ["240770601cc226190c367ef59aba7463"]; # AAC
          assign_scores_to = assignScore 100 englishProfiles;
        }

        # Softly deprioritize lossless/DTS audio and low-tier groups instead of hard-blocking
        {
          trash_ids = [
            "496f355514737f7d83bf7aa4d24f8169" # TrueHD ATMOS
            "3cafb66171b47f226146a0770576870f" # TrueHD
            "2f22d89048b01681dde8afe203bf2e95" # DTS X
            "dcf3ec6938fa32445f590a4da84256cd" # DTS-HD MA
            "8e109e50e0a0b83a5098b056e13bf6db" # DTS-HD HRA
          ];
          assign_scores_to = assignScore (-150) englishProfiles;
        }
        {
          trash_ids = [
            "90a6f9a284dff5103f6346090e6280c8" # LQ
            "e204b80c87be9497a8a6eaff48f72905" # LQ (Release Title)
          ];
          assign_scores_to = assignScore (-200) englishProfiles;
        }
        {
          trash_ids = [
            "ae9b7c9ebde1f3bd336a8cbd1ec4c5e5" # No-RlsGroup
          ];
          assign_scores_to = assignScore (-100) englishProfiles;
        }
      ];
    };
  };
}
