{lib, ...}: {
  # Load TCP BBR congestion control kernel module
  boot.kernelModules = ["tcp_bbr"];

  boot.kernel.sysctl = {
    # FQ queuing + BBR congestion control: keeps latency low and avoids
    # throughput collapses over WAN, Wi-Fi, WireGuard, and Tailscale
    "net.core.default_qdisc" = lib.mkDefault "fq";
    "net.ipv4.tcp_congestion_control" = lib.mkDefault "bbr";

    # Recover automatically from ICMP Path-MTU blackholes across VPN/mobile links
    "net.ipv4.tcp_mtu_probing" = lib.mkDefault 1;

    # Enable TCP Fast Open for both client and server sockets
    "net.ipv4.tcp_fastopen" = lib.mkDefault 3;

    # Adequate socket buffers for WireGuard/Tailscale UDP encapsulation
    "net.core.rmem_max" = lib.mkDefault 7500000;
    "net.core.wmem_max" = lib.mkDefault 7500000;
  };
}
