{pkgs, ...}: let
  sshKeygenWrapper = pkgs.writeShellScriptBin "ssh-keygen-wrapper" ''
    export PATH="${pkgs.lib.makeBinPath (with pkgs; [openssh coreutils gnugrep git])}:$PATH"
    ${builtins.readFile ./ssh_keygen_wrapper.sh}
  '';
in {
  home.packages = [
    sshKeygenWrapper
  ];
}
