{pkgs, ...}: {
  environment.systemPackages = with pkgs; [
    # file & disk
    fd
    ripgrep
    bat
    eza
    duf
    cifs-utils
    # network
    nmap
    dig
    traceroute
    # archives
    zip
    unzip
    # downloading
    wget
    curl
    # general
    git
    jq
    gcc
    # nix
    direnv
  ];
}
