{
  config,
  lib,
  ...
}: let
  inherit (lib) mkIf mkForce;
  cfg = config.server.arr;
in {
  config = mkIf (cfg.enable && cfg.recyclarr.enable && cfg.radarr.enable) {
    nixflix.recyclarr.config.radarr.radarr = {
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
  };
}
