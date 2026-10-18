{pkgs, ...}: let
  sendFile = pkgs.writeShellScriptBin "send_file" ''
    export PATH="${pkgs.lib.makeBinPath (with pkgs; [fzf kdePackages.kdeconnect-kde coreutils gnugrep gawk libnotify])}:$PATH"
    ${builtins.readFile ./send_file.sh}
  '';
in {
  home.packages = [
    sendFile
  ];
}
