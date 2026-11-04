{
  config,
  lib,
  ...
}: let
  inherit (lib) mkIf mkForce;
  cfg = config.server.arr;
in {
  config = mkIf (cfg.enable && cfg.recyclarr.enable && cfg.sonarr.enable) {
    nixflix.recyclarr.config = {
      sonarr.sonarr = {
        quality_definition.type = "series";

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
          }
        ];

        custom_formats = [
          {
            trash_ids = [
              "9b27ab6498ec0f31a3353992e19434ca" # DV (w/o HDR fallback)
            ];
            assign_scores_to = [
              {
                name = "4K (2160p) – Deutsch";
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
        ];
      };
    };
  };
}
