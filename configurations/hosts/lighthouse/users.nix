{pkgs, ...}: {
  users.users.luka = {
    isNormalUser = true;
    extraGroups = ["wheel" "networkmanager" "libvirtd"];
    shell = pkgs.fish;
  };
  home-manager.users.luka = import ../../home/luka-lighthouse.nix;
}
