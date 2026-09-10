{pkgs, ...}: {
  wayland.windowManager.hyprland = {
    enable = true;
    configType = "hyprlang";
    package = null; # Use system package from NixOS module

    settings = {
      "$mod" = "SUPER";

      # Monitor configuration
      # Primary 1440p 165Hz monitor (DP-3)
      # Secondary 1080p 165Hz monitor (DP-4) on the left
      monitor = [
        "desc:Acer Technologies XZ272U V, 2560x1440@165, 1920x0, 1"
        "desc:Samsung Electric Company LS24AG32x, 1920x1080@165, 0x176, 1"
        ", preferred, auto, 1"
      ];

      # Bind workspaces to monitors
      workspace = [
        "1, monitor:desc:Acer Technologies XZ272U V, default:true"
        "2, monitor:desc:Acer Technologies XZ272U V"
        "3, monitor:desc:Acer Technologies XZ272U V"
        "4, monitor:desc:Acer Technologies XZ272U V"
        "5, monitor:desc:Acer Technologies XZ272U V"
        "6, monitor:desc:Samsung Electric Company LS24AG32x, default:true"
        "7, monitor:desc:Samsung Electric Company LS24AG32x"
        "8, monitor:desc:Samsung Electric Company LS24AG32x"
        "9, monitor:desc:Samsung Electric Company LS24AG32x"
        "10, monitor:desc:Samsung Electric Company LS24AG32x"
      ];

      # Environment variables
      env = [
        "XDG_CURRENT_DESKTOP,Hyprland"
        "XDG_SESSION_TYPE,wayland"
        "XDG_SESSION_DESKTOP,Hyprland"
        "QT_QPA_PLATFORM,wayland;xcb"
        "QT_WAYLAND_DISABLE_WINDOWDECORATION,1"
        "QT_AUTO_SCREEN_SCALE_FACTOR,1"
        "GDK_BACKEND,wayland,x11,*"
        "CLUTTER_BACKEND,wayland"
        "HYPRCURSOR_THEME,Bibata-Modern-Classic"
        "HYPRCURSOR_SIZE,24"
        "XCURSOR_THEME,Bibata-Modern-Classic"
        "XCURSOR_SIZE,24"
      ];

      # Input configuration
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
          "tap-to-click" = true;
        };
      };

      # Look & feel
      general = {
        gaps_in = 5;
        gaps_out = 8;
        border_size = 2;
        "col.active_border" = "rgba(7aa2f7ee) rgba(bb9af7ee) 45deg";
        "col.inactive_border" = "rgba(414868aa)";
        layout = "dwindle";
        allow_tearing = false;
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

      animations = {
        enabled = true;
        bezier = "myBezier, 0.05, 0.9, 0.1, 1.05";
        animation = [
          "windows, 1, 5, myBezier"
          "windowsOut, 1, 5, default, popin 80%"
          "border, 1, 8, default"
          "borderangle, 1, 6, default"
          "fade, 1, 5, default"
          "workspaces, 1, 5, default"
        ];
      };

      dwindle = {
        preserve_split = true;
      };

      misc = {
        disable_hyprland_logo = true;
        disable_splash_rendering = true;
        mouse_move_enables_dpms = true;
        key_press_enables_dpms = true;
      };

      # Autostart core services
      exec-once = [
        "${pkgs.hyprpolkitagent}/libexec/hyprpolkitagent"
        "noctalia"
      ];

      # Keybindings
      bind = [
        # Core applications & Noctalia surfaces
        "$mod, Return, exec, ghostty"
        "$mod, Space, exec, noctalia msg panel-toggle launcher"
        "$mod, R, exec, rofi -show run"
        "$mod, V, exec, noctalia msg panel-toggle clipboard"
        "$mod, N, exec, noctalia msg panel-toggle control-center"
        "$mod, comma, exec, noctalia msg settings-toggle"
        "ALT, Tab, exec, noctalia msg window-switcher"
        "$mod, E, exec, nautilus"
        "$mod, B, exec, zen-beta"
        "$mod, L, exec, hyprlock"
        "$mod, Escape, exec, noctalia msg panel-toggle session"
        "$mod, X, exec, noctalia msg panel-toggle session"

        # Window management
        "$mod, Q, killactive"
        "$mod, C, killactive"
        "$mod SHIFT, Space, togglefloating"
        "$mod, F, fullscreen, 0"
        "$mod, P, pseudo"
        "$mod, J, layoutmsg, togglesplit"

        # Focus navigation
        "$mod, left, movefocus, l"
        "$mod, right, movefocus, r"
        "$mod, up, movefocus, u"
        "$mod, down, movefocus, d"
        "$mod, h, movefocus, l"
        "$mod, l, movefocus, r"
        "$mod, k, movefocus, u"
        "$mod, j, movefocus, d"

        # Window movement
        "$mod SHIFT, left, movewindow, l"
        "$mod SHIFT, right, movewindow, r"
        "$mod SHIFT, up, movewindow, u"
        "$mod SHIFT, down, movewindow, d"
        "$mod SHIFT, h, movewindow, l"
        "$mod SHIFT, l, movewindow, r"
        "$mod SHIFT, k, movewindow, u"
        "$mod SHIFT, j, movewindow, d"

        # Workspaces switch
        "$mod, 1, workspace, 1"
        "$mod, 2, workspace, 2"
        "$mod, 3, workspace, 3"
        "$mod, 4, workspace, 4"
        "$mod, 5, workspace, 5"
        "$mod, 6, workspace, 6"
        "$mod, 7, workspace, 7"
        "$mod, 8, workspace, 8"
        "$mod, 9, workspace, 9"
        "$mod, 0, workspace, 10"

        # Move active window to workspace
        "$mod SHIFT, 1, movetoworkspace, 1"
        "$mod SHIFT, 2, movetoworkspace, 2"
        "$mod SHIFT, 3, movetoworkspace, 3"
        "$mod SHIFT, 4, movetoworkspace, 4"
        "$mod SHIFT, 5, movetoworkspace, 5"
        "$mod SHIFT, 6, movetoworkspace, 6"
        "$mod SHIFT, 7, movetoworkspace, 7"
        "$mod SHIFT, 8, movetoworkspace, 8"
        "$mod SHIFT, 9, movetoworkspace, 9"
        "$mod SHIFT, 0, movetoworkspace, 10"

        # Special workspace (scratchpad)
        "$mod, S, togglespecialworkspace, magic"
        "$mod CTRL, S, movetoworkspace, special:magic"

        # Workspace mouse scrolling
        "$mod, mouse_down, workspace, e+1"
        "$mod, mouse_up, workspace, e-1"

        # Screenshots
        ", Print, exec, grim - | wl-copy && notify-send 'Screenshot' 'Copied to clipboard'"
        "$mod SHIFT, S, exec, grim -g \"$(slurp)\" - | wl-copy && notify-send 'Screenshot' 'Selection copied to clipboard'"
        "$mod, Print, exec, mkdir -p ~/Pictures/Screenshots && grim -g \"$(slurp)\" ~/Pictures/Screenshots/$(date +'%Y-%m-%d_%H-%M-%S').png && notify-send 'Screenshot' 'Saved to ~/Pictures/Screenshots'"
        "$mod SHIFT, Print, exec, grim -g \"$(slurp)\" - | swappy -f -"

        # Audio volume & mute
        ", XF86AudioRaiseVolume, exec, noctalia msg volume-up"
        ", XF86AudioLowerVolume, exec, noctalia msg volume-down"
        ", XF86AudioMute, exec, noctalia msg volume-mute"
        ", XF86AudioMicMute, exec, noctalia msg mic-mute"

        # Brightness
        ", XF86MonBrightnessUp, exec, noctalia msg brightness-up"
        ", XF86MonBrightnessDown, exec, noctalia msg brightness-down"

        # Media player controls
        ", XF86AudioPlay, exec, playerctl play-pause"
        ", XF86AudioNext, exec, playerctl next"
        ", XF86AudioPrev, exec, playerctl previous"
      ];

      # Keyboard window resizing (repeatable when held)
      binde = [
        "$mod CTRL, right, resizeactive, 25 0"
        "$mod CTRL, left, resizeactive, -25 0"
        "$mod CTRL, up, resizeactive, 0 -25"
        "$mod CTRL, down, resizeactive, 0 25"
        "$mod CTRL, l, resizeactive, 25 0"
        "$mod CTRL, h, resizeactive, -25 0"
        "$mod CTRL, k, resizeactive, 0 -25"
        "$mod CTRL, j, resizeactive, 0 25"
      ];

      # Mouse dragging and resizing
      bindm = [
        "$mod, mouse:272, movewindow"
        "$mod, mouse:273, resizewindow"
      ];

      # Window rules
      windowrule = [
        "float 1, match:class ^(pavucontrol)$"
        "float 1, match:class ^(org.pulseaudio.pavucontrol)$"
        "float 1, match:class ^(nm-connection-editor)$"
        "float 1, match:class ^(blueman-manager)$"
        "float 1, match:title ^(Open File|Save File|Choose Files)$"
        "float 1, match:class ^(xdg-desktop-portal-.*)$"
        "float 1, match:title ^(Picture-in-Picture)$"
        "pin 1, match:title ^(Picture-in-Picture)$"
        "idle_inhibit fullscreen, match:class ^(.*)$"
        "float 1, match:class ^(dev.noctalia.Noctalia)$"
        "size 1080 920, match:class ^(dev.noctalia.Noctalia)$"
      ];

      # Layer rules for Noctalia surfaces
      layerrule = [
        "no_anim 1, match:namespace ^(noctalia-.*)$"
        "blur 1, match:namespace ^(noctalia-.*)$"
        "ignore_alpha 0.5, match:namespace ^(noctalia-.*)$"
        "blur_popups 1, match:namespace ^(noctalia-.*)$"
      ];
    };
  };
}
