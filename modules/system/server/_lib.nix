# Shared helper functions across server modules (notification dispatch wrapper).
# Prefixed with '_' so lib/mod.nix does not auto-import this helper directly as a NixOS module.
{
  mkNotifyBin = {
    pkgs,
    lib,
    config,
    enable,
    handler,
    name,
    title,
  }: let
    notifyCfg = config.server.notify or {};
  in
    if !enable
    then ""
    else if handler != null
    then
      if builtins.isString handler
      then let
        customHandler = pkgs.writeShellApplication {
          inherit name;
          text = ''
            export PATH="''${PATH:+$PATH:}/run/current-system/sw/bin"
            ${handler}
          '';
        };
      in "${customHandler}/bin/${name}"
      else lib.getExe handler
    else if (notifyCfg.enable or false)
    then let
      defaultHandler = pkgs.writeShellApplication {
        inherit name;
        runtimeInputs = [pkgs.curl];
        text = ''
          MSG="''${1:-${title} notification}"
          TAG="''${2:-warning}"
          curl -fsS -m 5 \
            -H "Title: ${title}" \
            -H "Tags: $TAG" \
            -d "$MSG" \
            "http://127.0.0.1:${toString (notifyCfg.port or 2586)}/${notifyCfg.topic or "media"}" >/dev/null
        '';
      };
    in "${defaultHandler}/bin/${name}"
    else "";
}
