{
  pkgs,
  lib,
  ...
}: {
  home.packages = with pkgs; [
    # Screenshots and screen capture
    grim
    slurp
    swappy

    # Clipboard utilities
    wl-clipboard

    # Audio and brightness control
    pamixer
    brightnessctl
    playerctl
    pavucontrol

    # System and desktop integration
    libnotify
    hyprpolkitagent
    networkmanagerapplet
  ];
}
