{pkgs, ...}: let
  tuVpn = pkgs.writeShellScriptBin "tu-vpn" ''
    export PATH="${pkgs.lib.makeBinPath (with pkgs; [openconnect psmisc libnotify procps iproute2 coreutils])}:$PATH"
    ${builtins.readFile ./tu_vpn.sh}
  '';
in {
  home.packages = [
    tuVpn
  ];
}
