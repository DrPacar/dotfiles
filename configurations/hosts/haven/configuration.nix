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

  networking = {
    hostName = "haven";
    useNetworkd = true;
    useDHCP = false;
    networkmanager.enable = false;
    nameservers = [
      "1.1.1.1"
      "1.0.0.1"
    ];
  };

  systemd.network = {
    enable = true;
    networks."10-lan" = {
      matchConfig.Name = "eno1";
      networkConfig = {
        DHCP = "yes";
        IgnoreCarrierLoss = "3s";
        DNSDefaultRoute = false;
        Domains = [
          "~local"
          "~home.arpa"
          "~lan"
          "~lukpac.dev"
        ];
      };
      dhcpV4Config = {
        UseDNS = false; # Keep static Cloudflare nameservers (1.1.1.1) to avoid loops with local AdGuard
        RouteMetric = 100;
      };
    };
    wait-online.extraArgs = ["--interface=eno1"];
  };

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

  # Exclude eno1 from PCI runtime power management after powertop --auto-tune
  systemd.services.powertop.serviceConfig.ExecStartPost = [
    (pkgs.writeShellScript "powertop-keep-eno1-awake" ''
      if [ -w /sys/class/net/eno1/device/power/control ]; then
        echo on > /sys/class/net/eno1/device/power/control
      fi
    '')
  ];

  # Size eno1 RX/TX ring buffers for sustained NAS, WireGuard, and Tailscale bursts
  systemd.services.tune-eno1 = {
    description = "Configure eno1 NIC ring buffers";
    wantedBy = ["multi-user.target"];
    wants = ["sys-subsystem-net-devices-eno1.device"];
    after = ["sys-subsystem-net-devices-eno1.device"];
    before = ["systemd-networkd.service" "network.target"];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = pkgs.writeShellScript "tune-eno1" ''
        set -euo pipefail
        read -r cur_rx cur_tx < <(
          LC_ALL=C ${pkgs.ethtool}/bin/ethtool -g eno1 \
            | ${pkgs.gawk}/bin/awk '/Current hardware settings:/{in_cur=1} in_cur && /^RX:/{rx=$2} in_cur && /^TX:/{tx=$2} END{print rx+0, tx+0}'
        )
        if [ "$cur_rx" -ne 1024 ] || [ "$cur_tx" -ne 1024 ]; then
          ${pkgs.ethtool}/bin/ethtool -G eno1 rx 1024 tx 1024
        fi
      '';
    };
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
