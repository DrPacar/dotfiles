{
  config,
  pkgs,
  ...
}: {
  services.tailscale = {
    enable = true;
    openFirewall = true;

    extraSetFlags = [
      "--operator=${config.user.primary}"
    ];

    useRoutingFeatures = "client";
  };

  networking.firewall = {
    trustedInterfaces = [config.services.tailscale.interfaceName];
  };

  environment.systemPackages = with pkgs; [
    trayscale
  ];
}
