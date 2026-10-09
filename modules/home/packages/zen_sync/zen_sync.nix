{pkgs, ...}: let
  zenSync = pkgs.writeShellScriptBin "zen-sync" (builtins.readFile ./zen_sync.sh);
in {
  home.packages = [
    zenSync
  ];
}
