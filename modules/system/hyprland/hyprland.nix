{
  pkgs,
  lib,
  ...
}: {
  options.displays = {
    monitors = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [", preferred, auto, 1"];
      description = "Hyprland monitor configurations for this host.";
    };
    workspaces = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      description = "Hyprland workspace bindings for this host.";
    };
  };

  config = {
    programs.hyprland = {
      enable = true;
      xwayland.enable = true;
    };

    fonts.packages = with pkgs; [
      nerd-fonts.jetbrains-mono
      font-awesome
      noto-fonts
      noto-fonts-color-emoji
    ];

    security.polkit.enable = true;
    services.gnome.gnome-keyring.enable = true;
    services.upower.enable = true;
  };
}
