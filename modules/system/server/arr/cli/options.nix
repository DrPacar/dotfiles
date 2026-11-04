{lib, ...}: let
  inherit (lib) mkOption types;
in {
  options.server.arr.cli = {
    enable = mkOption {
      type = types.bool;
      default = true;
      example = false;
      description = "Whether to install the arr-status and arr CLI utilities in environment.systemPackages.";
    };
  };
}
