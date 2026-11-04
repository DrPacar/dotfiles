{
  config,
  lib,
  inputs,
  ...
}: let
  inherit (lib) mkIf mkMerge;
  cfg = config.server.arr;
in {
  imports = [
    inputs.nixflix.nixosModules.default
    (lib.mkAliasOptionModule ["arr"] ["server" "arr"])
  ];

  config = mkMerge [
    (mkIf (!config.server.enable) {
      server.arr.enable = lib.mkForce false;
    })
    (mkIf cfg.enable {
      # -------------------------------------------------------------------------
      # Base Nixflix Configuration
      # -------------------------------------------------------------------------
      nixflix = {
        enable = true;

        mediaDir = cfg.paths.media;
        downloadsDir = cfg.paths.torrents;
        mediaUsers = [cfg.mediaUser];

        # Disable public reverse proxies; services are accessed securely via Tailscale and localhost
        nginx.enable = false;
        caddy.enable = false;
      };
    })
  ];
}
