{ ... }:
{
  flake.homeModules.terminal =
    { pkgs, ... }:
    {
      programs.kitty = {
        enable = true;

        settings = {
          # 1. Fenster & Layout
          window_padding_width = 12;
          confirm_os_window_close = 0;
          background_opacity = "0.90";
          dynamic_background_opacity = true;

          # 2. Performance & Rendering
          repaint_delay = 8;
          input_delay = 1;
          sync_to_monitor = true;

          # 3. Cursor & Scrollback
          cursor_shape = "block";
          cursor_blink_interval = "0.5";
          scrollback_lines = 10000;

          # 4. Audio-Bell
          enable_audio_bell = false;

          # 5. Tab-Bar Styling
          tab_bar_edge = "top";
          tab_bar_style = "powerline";
          tab_powerline_style = "slanted";
        };
      };
    };
}