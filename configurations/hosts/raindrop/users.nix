{pkgs, ...}: {
  users.users.luka = {
    isNormalUser = true;
    extraGroups = ["wheel" "networkmanager"];
    shell = pkgs.fish;
  };

  home-manager.users.luka = import ../../home/luka-raindrop.nix;
}
