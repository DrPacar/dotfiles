{
  inputs,
  pkgs,
  config,
  ...
}: {
  imports = [
    inputs.noctalia-greeter.nixosModules.default
  ];

  # Disable GDM so Noctalia Greeter handles the display manager session
  services.displayManager.gdm.enable = false;

  # Noctalia Greeter configuration
  services.displayManager.noctalia-greeter = {
    enable = true;
    passwordless-sync-users = ["luka"];
    settings = {
      session = {
        default = "Hyprland";
      };
      user = {
        default = "luka";
      };
      appearance = {
        scheme = "Synced";
        theme_mode = "dark";
        font_family = "JetBrainsMono Nerd Font";
        hide_logo = true;
        password_style = "default";
        corner_radius_scale = 1.0;
        power_buttons_position = "bottom-right";
        scheme_selector_position = "hidden";
        palette = {
          primary = "#7aa2f7";
          on_primary = "#16161e";
          secondary = "#bb9af7";
          on_secondary = "#16161e";
          tertiary = "#9ece6a";
          on_tertiary = "#16161e";
          error = "#f7768e";
          on_error = "#16161e";
          surface = "#1a1b26";
          on_surface = "#c0caf5";
          surface_variant = "#24283b";
          on_surface_variant = "#9aa5ce";
          outline = "#353d57";
          shadow = "#15161e";
          hover = "#7aa2f7";
          on_hover = "#16161e";
        };
        wallpaper = {
          path = "${../../../wallpapers/rest.png}";
          fill_mode = "crop";
        };
      };
      clock = {
        enabled = true;
        position = "above-panel";
        time_format = "{:%H:%M}";
        date_format = "%A, %d. %B";
        time_font_size = 56;
        date_font_size = 15;
      };
      cursor = {
        theme = "Bibata-Modern-Classic";
        size = 24;
        path = "${pkgs.bibata-cursors}/share/icons";
      };
      keyboard = {
        layout = "at";
      };
    };
  };

  # Make GNOME session desktop file available in system environment
  # so greetd and Noctalia Greeter can discover it alongside Hyprland
  environment.systemPackages = [
    pkgs.gnome-session.sessions
    pkgs.bibata-cursors
  ];

  # Ensure greetd can discover sessions from displayManager.sessionData
  systemd.services.greetd.environment = {
    XDG_DATA_DIRS = "${config.services.displayManager.sessionData.desktops}/share:/run/current-system/sw/share";
  };

  # Automatically unlock GNOME keyring when logging in
  security.pam.services.greetd.enableGnomeKeyring = true;
}
