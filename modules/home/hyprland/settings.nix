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
}
