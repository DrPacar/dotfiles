{...}: {
  wayland.windowManager.hyprland.settings.config = {
    general = {
      gaps_in = 5;
      gaps_out = 8;
      border_size = 2;
      layout = "dwindle";
      allow_tearing = false;
      col = {
        active_border = {
          colors = ["rgba(7aa2f7ee)" "rgba(bb9af7ee)"];
          angle = 45;
        };
        inactive_border = "rgba(24283baa)";
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
      rounding = 12;
      active_opacity = 1.0;
      inactive_opacity = 0.94;

      blur = {
        enabled = true;
        size = 6;
        passes = 3;
        new_optimizations = true;
        vibrancy = 0.2;
      };

      shadow = {
        enabled = true;
        range = 20;
        render_power = 3;
        color = "rgba(16161ecc)";
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
}
