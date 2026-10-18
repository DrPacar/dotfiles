{
  inputs,
  pkgs,
  lib,
  ...
}: let
  secretsFile = ../../secrets/secrets.yaml;
  # Automatically parse all top-level keys from secrets.yaml
  content = builtins.readFile secretsFile;
  lines = lib.splitString "\n" content;
  extractKey = line: let
    m = builtins.match "^([a-zA-Z0-9_-]+):.*" line;
  in
    if m != null && (builtins.head m) != "sops"
    then builtins.head m
    else null;
  secretKeys = builtins.filter (x: x != null) (map extractKey lines);
in {
  imports = [
    inputs.sops-nix.nixosModules.sops
  ];

  sops = {
    defaultSopsFile = secretsFile;
    defaultSopsFormat = "yaml";
    age.keyFile = "/home/luka/.config/sops/age/keys.txt";

    secrets = lib.genAttrs secretKeys (_name: {
      group = "wheel";
      mode = "0440";
    });
  };

  environment.systemPackages = with pkgs; [
    sops
    age
  ];
}
