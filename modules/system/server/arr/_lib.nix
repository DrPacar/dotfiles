# Shared helper functions for the Arr stack (secret references and notification hooks).
let
  serverLib = import ../_lib.nix;
in {
  secretRef = secretPath:
    if secretPath != null
    then {_secret = secretPath;}
    else null;

  inherit (serverLib) mkNotifyBin;
}
