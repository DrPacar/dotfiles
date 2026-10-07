{pkgs, ...}: let
  # Package the standalone work_on.sh script as a system binary
  workOn = pkgs.writeShellScriptBin "work_on" (builtins.readFile ./work_on.sh);
in {
  home.packages = [
    workOn
  ];
}
