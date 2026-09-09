{lib, ...}: {
  services.hypridle = {
    enable = true;
    settings = {
      general = {
        lock_cmd = "pidof hyprlock || hyprlock";
        before_sleep_cmd = "loginctl lock-session";
        after_sleep_cmd = "hyprctl dispatch dpms on";
      };

      listener = [
        # Dim screen after 4.5 minutes
        {
          timeout = 270;
          on-timeout = "brightnessctl -s set 10%";
          on-resume = "brightnessctl -r";
        }
        # Lock screen after 5 minutes
        {
          timeout = 300;
          on-timeout = "loginctl lock-session";
        }
        # Turn off display after 6 minutes
        {
          timeout = 360;
          on-timeout = "hyprctl dispatch dpms off";
          on-resume = "hyprctl dispatch dpms on";
        }
        # Suspend system after 30 minutes
        {
          timeout = 1800;
          on-timeout = "systemctl suspend";
        }
      ];
    };
  };

  # Ensure hypridle runs only in Hyprland sessions, avoiding interference with GNOME
  systemd.user.services.hypridle.Install.WantedBy = lib.mkForce ["hyprland-session.target"];
}
