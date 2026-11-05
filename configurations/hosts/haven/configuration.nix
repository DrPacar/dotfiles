{
  config,
  pkgs,
  lib,
  mod,
  ...
}: {
  imports = [
    ./hardware-configuration.nix
    ./disk.nix
    ./users.nix
    ./boot.nix
    ./packages.nix
    ../base-system.nix
  ];

  networking.hostName = "haven";
  networking.nameservers = [
    "1.1.1.1"
    "1.0.0.1"
  ];

  networking.networkmanager = {
    enable = true;
    wifi.powersave = false;
  };
  systemd.services.NetworkManager-wait-online.enable = false;

  # Headless server: disable desktop / audio services from base-system.nix
  services.pipewire.enable = lib.mkForce false;
  security.rtkit.enable = lib.mkForce false;
  services.printing.enable = lib.mkForce false;
  services.flatpak.enable = lib.mkForce false;
  xdg.portal.enable = lib.mkForce false;

  # Power efficiency & hardware power saving
  powerManagement = {
    enable = true;
    cpuFreqGovernor = "powersave";
    powertop.enable = true;
    scsiLinkPolicy = "med_power_with_dipm";
  };

  # Set Intel P-State Energy Performance Preference to balance_power
  systemd.services.set-cpu-epp = {
    description = "Set CPU Energy Performance Preference to balance_power";
    wantedBy = ["multi-user.target"];
    after = ["systemd-modules-load.service"];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = "${pkgs.bash}/bin/bash -c 'for f in /sys/devices/system/cpu/cpu*/cpufreq/energy_performance_preference; do echo balance_power > \"$f\" 2>/dev/null || true; done'";
    };
  };

  # Reduce wakeups and enable audio power saving
  boot.kernel.sysctl = {
    "kernel.nmi_watchdog" = 0;
    "vm.dirty_writeback_centisecs" = 1500;
  };
  boot.extraModprobeConfig = ''
    options snd_hda_intel power_save=1
  '';

  system.stateVersion = "24.05";
}
