{
  inputs,
  pkgs,
  ...
}: {
  imports = [
    inputs.sops-nix.nixosModules.sops
  ];

  sops = {
    defaultSopsFile = ../../secrets/secrets.yaml;
    defaultSopsFormat = "yaml";
    age.keyFile = "/home/luka/.config/sops/age/keys.txt";

    secrets.tu_vpn_user = {
      group = "wheel";
      mode = "0440";
    };
  };

  environment.systemPackages = with pkgs; [
    sops
    age
  ];
}
