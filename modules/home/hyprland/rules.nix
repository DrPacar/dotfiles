{...}: {
  wayland.windowManager.hyprland.settings = {
    window_rule = [
      {
        match.class = "^(pavucontrol|org.pulseaudio.pavucontrol|nm-connection-editor|blueman-manager|org.kde.kdeconnect.*)$";
        float = true;
        center = true;
      }
      {
        match.class = "^(hyprpolkitagent|polkit-gnome-authentication-agent-1|org.kde.polkit-kde-authentication-agent-1|pinentry.*)$";
        float = true;
        center = true;
        dim_around = true;
      }
      {
        match.title = "^(Open File|Save File|Choose Files|File Operation Progress|Confirm to replace files)$";
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
        opaque = true;
        keep_aspect_ratio = true;
      }
      {
        match.class = "^(mpv|imv)$";
        float = true;
        center = true;
        opaque = true;
      }
      {
        match.class = "^(ripdrag|.*ripdrag.*)$";
        float = true;
        pin = true;
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
