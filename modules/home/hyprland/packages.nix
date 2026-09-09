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
    cliphist

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

  # Clipboard history daemon
  services.cliphist = {
    enable = true;
    allowImages = true;
  };

  # Ensure cliphist runs only in Hyprland sessions, avoiding duplicate daemons in GNOME
  systemd.user.services.cliphist.Install.WantedBy = lib.mkForce ["hyprland-session.target"];
  systemd.user.services.cliphist-images.Install.WantedBy = lib.mkForce ["hyprland-session.target"];
}
