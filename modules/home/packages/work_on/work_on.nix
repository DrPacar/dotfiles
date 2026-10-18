{pkgs, ...}: let
  # Package the standalone work_on.sh script as a system binary
  workOn = pkgs.writeShellScriptBin "work_on" ''
    export PATH="${pkgs.lib.makeBinPath (with pkgs; [typst zathura jq coreutils fzf procps])}:$PATH"
    ${builtins.readFile ./work_on.sh}
  '';
in {
  home.packages = [
    workOn
  ];
}
