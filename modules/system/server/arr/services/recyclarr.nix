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

      # Quality profiles and custom formats are colocated in their respective service modules:
      # - Radarr: ./radarr/recyclarr.nix
      # - Sonarr: ./sonarr/recyclarr.nix

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
