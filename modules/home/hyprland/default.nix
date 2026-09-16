{
  lib,
  osConfig,
  ...
}: let
  # Helper: Parses legacy monitor string (e.g. "desc:..., 2560x1440@165, 1920x0, 1") into Lua table
  parseMonitor = str: let
    parts = map (lib.strings.trim) (lib.splitString "," str);
    output = builtins.elemAt parts 0;
    mode = builtins.elemAt parts 1;
    position = builtins.elemAt parts 2;
    scaleStr = builtins.elemAt parts 3;
    parsedScale = builtins.tryEval (builtins.fromJSON scaleStr);
    scale =
      if parsedScale.success
      then parsedScale.value
      else scaleStr;
  in {
    inherit output mode position scale;
  };

  # Helper: Parses legacy workspace string (e.g. "1, monitor:desc:..., default:true") into workspace_rule
  parseWorkspace = str: let
    parts = map (lib.strings.trim) (lib.splitString "," str);
    ws = builtins.elemAt parts 0;
    rest = builtins.tail parts;
    getOpt = prefix: let
      matches = builtins.filter (lib.hasPrefix prefix) rest;
    in
      if matches != []
      then lib.removePrefix prefix (builtins.head matches)
      else null;
    mon = getOpt "monitor:";
    def = getOpt "default:";
  in
    {
      workspace = ws;
    }
    // lib.optionalAttrs (mon != null) {monitor = mon;}
    // lib.optionalAttrs (def == "true") {default = true;};
in {
  wayland.windowManager.hyprland = {
    enable = true;
    package = null; # Use system package from NixOS module

    # Switch to native Lua configuration
    configType = "lua";

    settings = {
      # Host monitor & workspace configuration
      monitor = map parseMonitor osConfig.displays.monitors;
      workspace_rule = map parseWorkspace osConfig.displays.workspaces;

      # Environment variables via hl.env(key, value)
      env = map (pair: {_args = pair;}) [
        ["XDG_CURRENT_DESKTOP" "Hyprland"]
        ["XDG_SESSION_TYPE" "wayland"]
        ["XDG_SESSION_DESKTOP" "Hyprland"]
        ["QT_QPA_PLATFORM" "wayland;xcb"]
        ["QT_WAYLAND_DISABLE_WINDOWDECORATION" "1"]
        ["QT_AUTO_SCREEN_SCALE_FACTOR" "1"]
        ["GDK_BACKEND" "wayland,x11,*"]
        ["CLUTTER_BACKEND" "wayland"]
        ["HYPRCURSOR_THEME" "Bibata-Modern-Classic"]
        ["HYPRCURSOR_SIZE" "24"]
        ["XCURSOR_THEME" "Bibata-Modern-Classic"]
        ["XCURSOR_SIZE" "24"]
        ["NIXOS_OZONE_WL" "1"]
        ["ELECTRON_OZONE_PLATFORM_HINT" "auto"]
        ["MOZ_ENABLE_WAYLAND" "1"]
      ];
    };
  };
}
