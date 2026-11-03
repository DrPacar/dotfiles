{pkgs, ...}: {
  user.primary = "luka";

  users.users.luka = {
    isNormalUser = true;
    extraGroups = [
      "wheel"
      "networkmanager"
      "video"
      "render"
    ];
    shell = pkgs.fish;
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAII9ahMh0Tcn58e2gANWRpyECO/zGO/At2tk7eD70KGxl luka@lighthouse"
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIEK+FcUtXmUuiDkdlye5eDnlWipnPwzQmBFVGogWvUlM luka@raindrop"
    ];
  };

  # Passwordless sudo for wheel ensures administrative access via SSH without initial interactive password prompt
  security.sudo.wheelNeedsPassword = false;

  home-manager.users.luka = import ../../home/luka-haven.nix;
}
