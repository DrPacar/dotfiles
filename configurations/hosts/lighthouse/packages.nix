{ pkgs, lib, mod, ... }: {
  imports = lib.concatMap mod [
    "base"
    "gaming"
    "gnome"
  ];
}
