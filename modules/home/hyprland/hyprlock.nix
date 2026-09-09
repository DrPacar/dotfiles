{...}: {
  programs.hyprlock = {
    enable = true;
    settings = {
      general = {
        disable_loading_bar = true;
        graceful_shutdown = true;
        hide_cursor = true;
        no_fade_in = false;
      };

      background = [
        {
          path = "screenshot";
          blur_passes = 3;
          blur_size = 8;
          noise = 0.0117;
          contrast = 0.8916;
          brightness = 0.8172;
          vibrancy = 0.1696;
          vibrancy_darkness = 0.0;
        }
      ];

      input-field = [
        {
          size = "280, 50";
          outline_thickness = 2;
          dots_size = 0.25;
          dots_spacing = 0.2;
          dots_center = true;
          outer_color = "rgb(122, 162, 247)";
          inner_color = "rgb(26, 27, 38)";
          font_color = "rgb(192, 202, 245)";
          fade_on_empty = false;
          placeholder_text = "<span foreground='##565f89'><i>Enter password...</i></span>";
          hide_input = false;
          position = "0, -60";
          halign = "center";
          valign = "center";
          check_color = "rgb(158, 206, 106)";
          fail_color = "rgb(247, 118, 142)";
          fail_text = "<i>$FAIL <b>($ATTEMPTS)</b></i>";
          fail_transition = 300;
        }
      ];

      label = [
        # Clock
        {
          text = "cmd[update:1000] date +\"%H:%M\"";
          color = "rgb(192, 202, 245)";
          font_size = 80;
          font_family = "JetBrainsMono Nerd Font Bold";
          position = "0, 100";
          halign = "center";
          valign = "center";
        }
        # Date
        {
          text = "cmd[update:1000] date +\"%A, %d %B %Y\"";
          color = "rgb(122, 162, 247)";
          font_size = 18;
          font_family = "JetBrainsMono Nerd Font";
          position = "0, 30";
          halign = "center";
          valign = "center";
        }
      ];
    };
  };
}
