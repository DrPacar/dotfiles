{ pkgs, lib, mod, ... }: {
  imports = lib.concatMap mod [
    "steam"
  ];
}
