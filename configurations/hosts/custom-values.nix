{lib, ...}: {
  options.user.primary = lib.mkOption {
    type = lib.types.str;
    default = "luka";
    description = "The primary user of the machine.";
  };
}
