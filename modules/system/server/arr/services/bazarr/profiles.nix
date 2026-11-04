{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (lib) mkIf;
  cfg = config.server.arr;
  bazarrUser = "bazarr";
in {
  config = mkIf (cfg.enable && cfg.bazarr.enable) {
    systemd.services.bazarr-setup-profile = {
      description = "Ensure default language profiles in Bazarr database";
      before = ["bazarr.service"];
      wantedBy = ["multi-user.target"];

      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        User = bazarrUser;
        Group = cfg.mediaGroup;
        StateDirectory = "bazarr";
        Slice = "arr.slice";
      };

      script = ''
        exec ${pkgs.python3}/bin/python3 ${../../scripts/bazarr-setup.py} /var/lib/bazarr/db
      '';
    };
  };
}
