{
  pkgs,
  lib,
  osConfig,
  ...
}: let
  lua = lib.generators.mkLuaInline;
  luaFunc = func:
    lua ''
      function()
        ${func}
      end
    '';

  mod = "SUPER";

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

      # Static settings rendered inside hl.config({ ... })
      config = {
        general = {
          gaps_in = 5;
          gaps_out = 8;
          border_size = 2;
          layout = "dwindle";
          allow_tearing = false;
          col = {
            active_border = {
              colors = ["rgba(37f499ee)" "rgba(04d1f9ee)"];
              angle = 45;
            };
            inactive_border = "rgba(292e42aa)";
          };
        };

        input = {
          kb_layout = "at";
          kb_variant = "";
          kb_model = "";
          kb_options = "";
          kb_rules = "";

          follow_mouse = 1;
          sensitivity = 0;

          touchpad = {
            natural_scroll = true;
            tap_to_click = true;
          };
        };

        decoration = {
          rounding = 10;
          active_opacity = 1.0;
          inactive_opacity = 0.95;

          blur = {
            enabled = true;
            size = 6;
            passes = 2;
            new_optimizations = true;
          };

          shadow = {
            enabled = true;
            range = 15;
            render_power = 3;
            color = "rgba(16161e99)";
          };
        };

        dwindle = {
          preserve_split = true;
          smart_split = false;
          smart_resizing = true;
        };

        misc = {
          disable_hyprland_logo = true;
          disable_splash_rendering = true;
          mouse_move_enables_dpms = true;
          key_press_enables_dpms = true;
          vrr = 0;
        };
      };

      # Autostart core services
      on = [
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

      # Animation curves & definitions
      curve = [
        {
          _args = [
            "myBezier"
            {
              type = "bezier";
              points = [[0.05 0.9] [0.1 1.05]];
            }
          ];
        }
      ];

      animation = [
        {
          leaf = "windows";
          enabled = true;
          speed = 5;
          bezier = "myBezier";
        }
        {
          leaf = "windowsOut";
          enabled = true;
          speed = 5;
          bezier = "default";
          style = "popin 80%";
        }
        {
          leaf = "border";
          enabled = true;
          speed = 8;
          bezier = "default";
        }
        {
          leaf = "borderangle";
          enabled = true;
          speed = 6;
          bezier = "default";
        }
        {
          leaf = "fade";
          enabled = true;
          speed = 5;
          bezier = "default";
        }
        {
          leaf = "workspaces";
          enabled = true;
          speed = 5;
          bezier = "default";
        }
      ];

      # Keybindings
      bind =
        [
          # Core applications & Noctalia surfaces
          {_args = ["${mod} + Return" (lua ''hl.dsp.exec_cmd("ghostty")'')];}
          {_args = ["${mod} + Space" (lua ''hl.dsp.exec_cmd("noctalia msg panel-toggle launcher")'')];}
          {_args = ["${mod} + period" (lua ''hl.dsp.exec_cmd("noctalia msg panel-toggle launcher /emo")'')];}
          {_args = ["${mod} + slash" (lua ''hl.dsp.exec_cmd("noctalia msg panel-toggle launcher /calc")'')];}
          {_args = ["${mod} + V" (lua ''hl.dsp.exec_cmd("noctalia msg panel-toggle clipboard")'')];}
          {_args = ["${mod} + N" (lua ''hl.dsp.exec_cmd("noctalia msg panel-toggle control-center")'')];}
          {_args = ["${mod} + comma" (lua ''hl.dsp.exec_cmd("noctalia msg settings-toggle")'')];}
          {_args = ["ALT + Tab" (lua ''hl.dsp.exec_cmd("noctalia msg window-switcher")'')];}
          {_args = ["${mod} + E" (lua ''hl.dsp.exec_cmd("nautilus")'')];}
          {_args = ["${mod} + B" (lua ''hl.dsp.exec_cmd("zen-beta")'')];}
          {_args = ["${mod} + L" (lua ''hl.dsp.exec_cmd("noctalia msg session lock")'')];}
          {_args = ["${mod} + Escape" (lua ''hl.dsp.exec_cmd("noctalia msg panel-toggle session")'')];}
          {_args = ["${mod} + W" (lua ''hl.dsp.exec_cmd("noctalia msg wallpaper-random")'')];}

          # Window management
          {_args = ["${mod} + Q" (lua "hl.dsp.window.close()")];}
          {_args = ["${mod} + SHIFT + Space" (lua ''hl.dsp.window.float({ action = "toggle" })'')];}
          {_args = ["${mod} + F" (lua "hl.dsp.window.fullscreen({ mode = 0 })")];}
          {_args = ["${mod} + P" (lua "hl.dsp.window.pseudo()")];}
          {_args = ["${mod} + T" (lua ''hl.dsp.layout("togglesplit")'')];}
          {_args = ["${mod} + G" (lua "hl.dsp.group.toggle()")];}
          {_args = ["${mod} + ALT + Tab" (lua "hl.dsp.group.next()")];}

          # Focus navigation
          {_args = ["${mod} + Left" (lua ''hl.dsp.focus({ direction = "l" })'')];}
          {_args = ["${mod} + Right" (lua ''hl.dsp.focus({ direction = "r" })'')];}
          {_args = ["${mod} + Up" (lua ''hl.dsp.focus({ direction = "u" })'')];}
          {_args = ["${mod} + Down" (lua ''hl.dsp.focus({ direction = "d" })'')];}
          {_args = ["${mod} + H" (lua ''hl.dsp.focus({ direction = "l" })'')];}
          {_args = ["${mod} + L" (lua ''hl.dsp.focus({ direction = "r" })'')];}
          {_args = ["${mod} + K" (lua ''hl.dsp.focus({ direction = "u" })'')];}
          {_args = ["${mod} + J" (lua ''hl.dsp.focus({ direction = "d" })'')];}

          # Cross-monitor navigation & window moving
          {_args = ["${mod} + O" (lua ''hl.dsp.focus({ monitor = "+1" })'')];}
          {_args = ["${mod} + SHIFT + O" (lua ''hl.dsp.window.move({ monitor = "+1" })'')];}

          # Window movement
          {_args = ["${mod} + SHIFT + Left" (lua ''hl.dsp.window.move({ direction = "l" })'')];}
          {_args = ["${mod} + SHIFT + Right" (lua ''hl.dsp.window.move({ direction = "r" })'')];}
          {_args = ["${mod} + SHIFT + Up" (lua ''hl.dsp.window.move({ direction = "u" })'')];}
          {_args = ["${mod} + SHIFT + Down" (lua ''hl.dsp.window.move({ direction = "d" })'')];}
          {_args = ["${mod} + SHIFT + H" (lua ''hl.dsp.window.move({ direction = "l" })'')];}
          {_args = ["${mod} + SHIFT + L" (lua ''hl.dsp.window.move({ direction = "r" })'')];}
          {_args = ["${mod} + SHIFT + K" (lua ''hl.dsp.window.move({ direction = "u" })'')];}
          {_args = ["${mod} + SHIFT + J" (lua ''hl.dsp.window.move({ direction = "d" })'')];}

          # Special workspace (scratchpad)
          {_args = ["${mod} + S" (lua ''hl.dsp.workspace.toggle_special("magic")'')];}
          {_args = ["${mod} + CTRL + S" (lua ''hl.dsp.window.move({ workspace = "special:magic" })'')];}

          # Workspace mouse scrolling
          {_args = ["${mod} + mouse_down" (lua ''hl.dsp.focus({ workspace = "e+1" })'')];}
          {_args = ["${mod} + mouse_up" (lua ''hl.dsp.focus({ workspace = "e-1" })'')];}

          # Screenshots via Noctalia native suite
          {_args = ["Print" (lua ''hl.dsp.exec_cmd("noctalia msg screenshot-fullscreen")'')];}
          {_args = ["${mod} + SHIFT + S" (lua ''hl.dsp.exec_cmd("noctalia msg screenshot-region")'')];}
          {_args = ["${mod} + SHIFT + Print" (lua ''hl.dsp.exec_cmd("noctalia msg screenshot-annotate")'')];}

          # Audio volume & mute
          {
            _args = [
              "XF86AudioRaiseVolume"
              (lua ''hl.dsp.exec_cmd("noctalia msg volume-up")'')
              {
                locked = true;
                repeating = true;
              }
            ];
          }
          {
            _args = [
              "XF86AudioLowerVolume"
              (lua ''hl.dsp.exec_cmd("noctalia msg volume-down")'')
              {
                locked = true;
                repeating = true;
              }
            ];
          }
          {_args = ["XF86AudioMute" (lua ''hl.dsp.exec_cmd("noctalia msg volume-mute")'') {locked = true;}];}
          {_args = ["XF86AudioMicMute" (lua ''hl.dsp.exec_cmd("noctalia msg mic-mute")'') {locked = true;}];}

          # Brightness
          {
            _args = [
              "XF86MonBrightnessUp"
              (lua ''hl.dsp.exec_cmd("noctalia msg brightness-up")'')
              {
                locked = true;
                repeating = true;
              }
            ];
          }
          {
            _args = [
              "XF86MonBrightnessDown"
              (lua ''hl.dsp.exec_cmd("noctalia msg brightness-down")'')
              {
                locked = true;
                repeating = true;
              }
            ];
          }

          # Media player controls
          {_args = ["XF86AudioPlay" (lua ''hl.dsp.exec_cmd("noctalia msg media play-pause")'') {locked = true;}];}
          {_args = ["XF86AudioNext" (lua ''hl.dsp.exec_cmd("noctalia msg media next")'') {locked = true;}];}
          {_args = ["XF86AudioPrev" (lua ''hl.dsp.exec_cmd("noctalia msg media previous")'') {locked = true;}];}

          # Keyboard window resizing (repeatable when held)
          {_args = ["${mod} + CTRL + Right" (lua "hl.dsp.window.resize({ x = 25, y = 0, relative = true })") {repeating = true;}];}
          {_args = ["${mod} + CTRL + Left" (lua "hl.dsp.window.resize({ x = -25, y = 0, relative = true })") {repeating = true;}];}
          {_args = ["${mod} + CTRL + Up" (lua "hl.dsp.window.resize({ x = 0, y = -25, relative = true })") {repeating = true;}];}
          {_args = ["${mod} + CTRL + Down" (lua "hl.dsp.window.resize({ x = 0, y = 25, relative = true })") {repeating = true;}];}
          {_args = ["${mod} + CTRL + L" (lua "hl.dsp.window.resize({ x = 25, y = 0, relative = true })") {repeating = true;}];}
          {_args = ["${mod} + CTRL + H" (lua "hl.dsp.window.resize({ x = -25, y = 0, relative = true })") {repeating = true;}];}
          {_args = ["${mod} + CTRL + K" (lua "hl.dsp.window.resize({ x = 0, y = -25, relative = true })") {repeating = true;}];}
          {_args = ["${mod} + CTRL + J" (lua "hl.dsp.window.resize({ x = 0, y = 25, relative = true })") {repeating = true;}];}

          # Mouse dragging and resizing
          {_args = ["${mod} + mouse:272" (lua "hl.dsp.window.drag()") {mouse = true;}];}
          {_args = ["${mod} + mouse:273" (lua "hl.dsp.window.resize()") {mouse = true;}];}
        ]
        # Workspaces 1..10 switch and move
        ++ builtins.concatLists (builtins.genList (
            i: let
              ws = toString (
                if i == 9
                then 10
                else i + 1
              );
              key = toString (
                if i == 9
                then 0
                else i + 1
              );
            in [
              {_args = ["${mod} + ${key}" (lua "hl.dsp.focus({ workspace = ${ws} })")];}
              {_args = ["${mod} + SHIFT + ${key}" (lua "hl.dsp.window.move({ workspace = ${ws} })")];}
            ]
          )
          10);

      # Window rules
      window_rule = [
        {
          match.class = "^(pavucontrol|org.pulseaudio.pavucontrol|nm-connection-editor|blueman-manager)$";
          float = true;
          center = true;
        }
        {
          match.title = "^(Open File|Save File|Choose Files)$";
          float = true;
          center = true;
        }
        {
          match.class = "^(xdg-desktop-portal-.*)$";
          float = true;
        }
        {
          match.title = "^(Picture-in-Picture)$";
          float = true;
          pin = true;
          move = "100%-w-20 100%-h-20";
        }
        {
          match.class = ".*";
          idle_inhibit = "fullscreen";
        }
        {
          match.class = "^(dev.noctalia.Noctalia)$";
          float = true;
          size = "1080 920";
        }
        {
          match.class = "^(steam_app_.*|gamescope)$";
          immediate = true;
        }
      ];

      # Layer rules for Noctalia surfaces
      layer_rule = [
        {
          match.namespace = "^(noctalia-.*)$";
          no_anim = true;
          blur = true;
          ignore_alpha = 0.5;
          blur_popups = true;
        }
      ];
    };
  };
}
