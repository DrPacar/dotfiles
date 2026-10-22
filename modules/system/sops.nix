{
  config,
  inputs,
  pkgs,
  lib,
  ...
}: let
  hostName = config.networking.hostName;

  commonSecretsFile = ../../secrets/common.yaml;
  hostSecretsFile = ../../secrets/${hostName}.yaml;

  extractKeys = file:
    if builtins.pathExists file
    then let
      content = builtins.readFile file;
      lines = lib.splitString "\n" content;
      extractKey = line: let
        m = builtins.match "^([a-zA-Z0-9_-]+):.*" line;
      in
        if m != null && (builtins.head m) != "sops"
        then builtins.head m
        else null;
    in
      builtins.filter (x: x != null) (map extractKey lines)
    else [];

  commonKeys = extractKeys commonSecretsFile;
  hostKeys = extractKeys hostSecretsFile;

  mkSecretEntry = file: name: {
    inherit name;
    value = {
      sopsFile = file;
      group = lib.mkDefault "wheel";
      mode = lib.mkDefault "0440";
    };
  };

  allSecrets =
    (builtins.listToAttrs (map (mkSecretEntry commonSecretsFile) commonKeys))
    // (builtins.listToAttrs (map (mkSecretEntry hostSecretsFile) hostKeys));
in {
  imports = [
    inputs.sops-nix.nixosModules.sops
  ];

  sops = {
    defaultSopsFormat = "yaml";
    age.keyFile = "/home/luka/.config/sops/age/keys.txt";

    secrets = allSecrets;
  };

  environment.systemPackages = with pkgs; [
    sops
    age
  ];
}
