{
  config,
  lib,
  ...
}: let
  inherit (lib) mkIf optionalAttrs;
  cfg = config.server.arr;
  brand = cfg.jellyfin.branding;
in {
  config = mkIf (cfg.enable && cfg.jellyfin.enable) {
    nixflix.jellyfin.branding =
      {
        customCss = mkIf cfg.jellyfin.theme.enable cfg.jellyfin.theme.customCss;
        loginDisclaimer = brand.loginDisclaimer;
        splashscreenEnabled = brand.splashscreenEnabled;
      }
      // optionalAttrs (brand.splashscreenLocation != null) {
        splashscreenLocation = brand.splashscreenLocation;
      };
  };
}
