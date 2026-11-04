{lib, ...}: let
  inherit (lib) mkOption types;
in {
  options.server.arr.recyclarr = {
    enable = mkOption {
      type = types.bool;
      default = true;
      description = "Enable Recyclarr automated TRaSH guides syncing.";
    };

    schedule = mkOption {
      type = types.str;
      default = "daily";
      example = "03:00";
      description = "When to run Recyclarr automated TRaSH sync in systemd calendar format.";
    };

    cleanupUnmanagedProfiles = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = "Automatically remove unmanaged default quality profiles (Any, SD, 720p, etc.) from Radarr and Sonarr to keep Jellyseerr dropdowns clutter-free.";
      };

      managedProfiles = mkOption {
        type = types.listOf types.str;
        default = [
          "Full HD (1080p) – Deutsch"
          "Full HD (1080p) – Englisch"
          "4K (2160p) – Deutsch"
          "4K (2160p) – Englisch"
          "Anime (1080p) – Japanisch (Sub)"
          "Anime (1080p) – Deutsch (Dub)"
          "Anime (1080p) – Englisch (Dub)"
        ];
        description = "List of quality profiles to preserve in Sonarr and Radarr during cleanup.";
      };
    };
  };
}
