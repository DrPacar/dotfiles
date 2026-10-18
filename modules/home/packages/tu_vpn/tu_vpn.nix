{pkgs, ...}: let
  tuVpn = pkgs.writeShellScriptBin "tu-vpn" ''
    export PATH="${pkgs.lib.makeBinPath (with pkgs; [openconnect coreutils gnused])}:$PATH"
    ${builtins.readFile ./tu_vpn.sh}
  '';
in {
  home.packages = [
    tuVpn
  ];
}
