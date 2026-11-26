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
  allProfiles =
    englishProfiles
    ++ [
      "Full HD (1080p) – Deutsch"
      "4K (2160p) – Deutsch"
      "Anime (1080p) – Japanisch (Sub)"
      "Anime (1080p) – Deutsch (Dub)"
      "Anime (1080p) – Englisch (Dub)"
    ];
  assignScore = score: profiles:
    map (name: {
      inherit name score;
    })
    profiles;
in {
  config = mkIf (cfg.enable && cfg.recyclarr.enable && cfg.sonarr.enable) {
    nixflix.recyclarr.config = {
      sonarr.sonarr = {
        quality_definition = {
          type = "anime";
          qualities = [
            {
              name = "Bluray-2160p";
              min = 25;
              preferred = 120;
              max = 250;
            }
            {
              name = "WEBDL-2160p";
              min = 20;
              preferred = 90;
              max = 180;
            }
            {
              name = "WEBRip-2160p";
              min = 20;
              preferred = 90;
              max = 180;
            }
            {
              name = "Bluray-1080p";
              min = 5;
              preferred = 45;
              max = 200;
            }
            {
              name = "Bluray-1080p Remux";
              min = 5;
              preferred = 45;
              max = 75;
            }
            {
              name = "WEBDL-1080p";
              min = 5;
              preferred = 35;
              max = 60;
            }
            {
              name = "WEBRip-1080p";
              min = 5;
              preferred = 35;
              max = 60;
            }
            {
              name = "HDTV-1080p";
              min = 5;
              preferred = 35;
              max = 60;
            }
            {
              name = "Bluray-720p";
              min = 5;
              preferred = 25;
              max = 45;
            }
            {
              name = "WEBDL-720p";
              min = 5;
              preferred = 20;
              max = 35;
            }
            {
              name = "WEBRip-720p";
              min = 5;
              preferred = 20;
              max = 35;
            }
            {
              name = "HDTV-720p";
              min = 5;
              preferred = 20;
              max = 35;
            }
          ];
        };

        quality_profiles = mkForce [
          {
            name = "Full HD (1080p) – Deutsch";
            trash_id = "dca7e5e9e99c703bcbdaaa471dd40e98"; # [German] HD Bluray + WEB
            reset_unmatched_scores.enabled = true;
            min_format_score = 10000;
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
            min_format_score = 10000;
          }
          {
            name = "4K (2160p) – Englisch";
            trash_id = "dfa5eaae7894077ad6449169b6eb03e0"; # WEB-2160p (Alternative)
            reset_unmatched_scores.enabled = true;
          }
          {
            name = "Anime (1080p) – Japanisch (Sub)";
            trash_id = "20e0fc959f1f1704bed501f23bdae76f"; # [Anime] Remux-1080p
            reset_unmatched_scores.enabled = true;
            min_format_score = 0;
            qualities = [
              {name = "Bluray-1080p";}
              {
                name = "WEB 1080p";
                qualities = [
                  "HDTV-1080p"
                  "WEBRip-1080p"
                  "WEBDL-1080p"
                ];
              }
              {name = "Bluray-720p";}
              {
                name = "WEB 720p";
                qualities = [
                  "HDTV-720p"
                  "WEBRip-720p"
                  "WEBDL-720p"
                ];
              }
              {name = "Bluray-480p";}
              {
                name = "WEB 480p";
                qualities = [
                  "WEBRip-480p"
                  "WEBDL-480p"
                ];
              }
              {name = "DVD";}
              {name = "SDTV";}
            ];
          }
          {
            name = "Anime (1080p) – Deutsch (Dub)";
            trash_id = "6fe5937e1dcc2269e23b49eb46dfe6d6"; # [German] Anime HD Bluray + WEB
            reset_unmatched_scores.enabled = true;
            min_format_score = 10000;
          }
          {
            name = "Anime (1080p) – Englisch (Dub)";
            trash_id = "20e0fc959f1f1704bed501f23bdae76f"; # [Anime] Remux-1080p
            reset_unmatched_scores.enabled = true;
            min_format_score = 0;
            qualities = [
              {name = "Bluray-1080p";}
              {
                name = "WEB 1080p";
                qualities = [
                  "HDTV-1080p"
                  "WEBRip-1080p"
                  "WEBDL-1080p"
                ];
              }
              {name = "Bluray-720p";}
              {
                name = "WEB 720p";
                qualities = [
                  "HDTV-720p"
                  "WEBRip-720p"
                  "WEBDL-720p"
                ];
              }
              {name = "Bluray-480p";}
              {
                name = "WEB 480p";
                qualities = [
                  "WEBRip-480p"
                  "WEBDL-480p"
                ];
              }
              {name = "DVD";}
              {name = "SDTV";}
            ];
          }
        ];

        custom_formats = [
          {
            trash_ids = [
              "47435ece6b99a0b477caf360e79ba0bb" # x265 (HD)
            ];
            assign_scores_to = [
              {
                name = "Full HD (1080p) – Englisch";
                score = 0; # Do not ban x265 (HD) season packs when x264 is unavailable
              }
              {
                name = "Full HD (1080p) – Deutsch";
                score = 0;
              }
            ];
          }
          {
            trash_ids = [
              "9b27ab6498ec0f31a3353992e19434ca" # DV (w/o HDR fallback)
            ];
            assign_scores_to = [
              {
                name = "4K (2160p) – Deutsch";
                score = -10000;
              }
              {
                name = "4K (2160p) – Englisch";
                score = -10000;
              }
            ];
          }
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
          {
            trash_ids = [
              "15a05bc7c1a36e2b57fd628f8977e2fc" # AV1 (software decode fallback risk on older iGPUs)
            ];
            assign_scores_to = assignScore (-10000) allProfiles;
          }
          {
            trash_ids = ["4232a509ce60c4e208d13825b7c06264"]; # DD+ ATMOS
            assign_scores_to = assignScore 250 englishProfiles;
          }
          {
            trash_ids = ["63487786a8b01b7f20dd2bc90dd4a477"]; # DD+
            assign_scores_to = assignScore 200 englishProfiles;
          }
          {
            trash_ids = ["a50b8a0c62274a7c38b09a9619ba9d86"]; # AAC
            assign_scores_to = assignScore 100 englishProfiles;
          }
          {
            trash_ids = [
              "0d7824bb924701997f874e7ff7d4844a" # TrueHD ATMOS
              "1808e4b9cee74e064dfae3f1db99dbfe" # TrueHD
              "9d00418ba386a083fbf4d58235fc37ef" # DTS X
              "c429417a57ea8c41d57e6990a8b0033f" # DTS-HD MA
              "cfa5fbd8f02a86fc55d8d223d06a5e1f" # DTS-HD HRA
            ];
            assign_scores_to = assignScore (-150) englishProfiles;
          }
          {
            trash_ids = [
              "9c11cd3f07101cdba90a2d81cf0e56b4" # LQ
              "e2315f990da2e2cbfc9fa5b7a6fcfe48" # LQ (Release Title)
            ];
            assign_scores_to = assignScore (-200) englishProfiles;
          }
          {
            trash_ids = [
              "82d40da2bc6923f41e14394075dd4b03" # No-RlsGroup
            ];
            assign_scores_to = assignScore (-100) englishProfiles;
          }
          {
            trash_ids = [
              "9965a052eb87b0d10313b1cea89eb451" # Remux Tier 01
              "8a1d0c3d7497e741736761a1da866a2e" # Remux Tier 02
            ];
            assign_scores_to = assignScore (-10000) [
              "Anime (1080p) – Japanisch (Sub)"
              "Anime (1080p) – Englisch (Dub)"
            ];
          }
        ];
      };
    };
  };
}
