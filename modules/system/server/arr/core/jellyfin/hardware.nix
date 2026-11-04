{
  config,
  pkgs,
  lib,
  ...
}: let
  inherit (lib) mkIf optionals;
  cfg = config.server.arr;
  jellyfinUser = "jellyfin";
in {
  config = mkIf (cfg.enable && cfg.jellyfin.enable) {
    hardware.graphics = mkIf (cfg.jellyfin.hardwareAcceleration != "none") {
      enable = true;
      extraPackages =
        [
          pkgs.intel-media-driver
          pkgs.intel-compute-runtime
        ]
        ++ optionals (cfg.jellyfin.hardwareAcceleration == "qsv") [
          pkgs.vpl-gpu-rt
        ];
    };

    users.users.${jellyfinUser}.extraGroups =
      mkIf (cfg.jellyfin.hardwareAcceleration != "none") ["video" "render"];
  };
}
