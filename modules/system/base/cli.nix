{ pkgs, ...}: {
  environment.systemPackages = with pkgs; [
    # archives
    zip
    unzip
    ouch
    # downloading
    wget
  ];
}
