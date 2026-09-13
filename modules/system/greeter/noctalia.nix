{
  inputs,
  pkgs,
  config,
  ...
}: {
  imports = [
    inputs.noctalia-greeter.nixosModules.default
  ];

  # Disable GDM so Noctalia Greeter (greetd) handles the display manager session
  services.displayManager.gdm.enable = false;

  # Noctalia Greeter configuration
  programs.noctalia-greeter = {
    enable = true;
    passwordless-sync-users = ["luka"];
    settings = {
      session = {
        default = "Hyprland";
      };
      user = {
        default = "luka";
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
