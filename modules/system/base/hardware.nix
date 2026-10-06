{
  config,
  lib,
  ...
}: {
  options = {
    device = {
      hasBattery = lib.mkOption {
        type = lib.types.bool;
        default = config.hardware.battery.enable;
        description = "Whether the host device has a battery.";
      };
    };

    hardware.battery = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Whether the host device has a battery.";
      };
    };
  };
}
