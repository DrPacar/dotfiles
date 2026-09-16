{
  pkgs,
  lib,
  ...
}: let
  inherit (import ./_lib.nix {inherit lib;}) luaFunc;
in {
  wayland.windowManager.hyprland.settings.on = [
    {
      _args = [
        "hyprland.start"
        (luaFunc ''
          hl.exec_cmd("${pkgs.hyprpolkitagent}/libexec/hyprpolkitagent")
          hl.exec_cmd("noctalia")
        '')
      ];
    }
  ];
}
