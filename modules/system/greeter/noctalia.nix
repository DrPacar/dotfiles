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
        hide_logo = false;
        power_buttons_position = "bottom-right";
        scheme_selector_position = "hidden";
        palette = {
          primary = "#37f499";
          on_primary = "#171928";
          secondary = "#04d1f9";
          on_secondary = "#171928";
          tertiary = "#a48cf2";
          on_tertiary = "#171928";
          error = "#f16c75";
          on_error = "#171928";
          surface = "#212337";
          on_surface = "#ebfafa";
          surface_variant = "#292e42";
          on_surface_variant = "#abb4da";
          outline = "#3b4261";
          shadow = "#414868";
          hover = "#a48cf2";
          on_hover = "#171928";
        };
        wallpaper = {
          path = "${../../../wallpapers/fall_forest.jpeg}";
          fill_mode = "crop";
        };
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
