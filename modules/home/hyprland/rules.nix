{...}: {
  wayland.windowManager.hyprland.settings = {
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
}
