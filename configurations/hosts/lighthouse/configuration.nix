{
  config,
  pkgs,
  mod,
  ...
}: {
  imports = [
    ./hardware-configuration.nix
    ./disk.nix
    ./users.nix
    ./boot.nix
    ./packages.nix
    ./monitors.nix
    ../base-system.nix
  ];

  networking.hostName = "lighthouse";

  networking.networkmanager = {
    enable = true;
    wifi.powersave = false;
  };
  systemd.services.NetworkManager-wait-online.enable = false;

  # Prevent Intel CNVi Wi-Fi (AX201 / AX211 - iwlwifi) from dropping connection during streaming
  boot.extraModprobeConfig = ''
    options iwlmvm power_scheme=1
    options iwlwifi power_save=0
    options iwlwifi uapsd_disable=1
  '';

  system.stateVersion = "24.05";
}
