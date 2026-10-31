{...}: {
  wayland.windowManager.hyprland.settings = {
    curve = [
      {
        _args = [
          "easeOutQuint"
          {
            type = "bezier";
            points = [[0.23 1] [0.32 1]];
          }
        ];
      }
      {
        _args = [
          "easeInOutCubic"
          {
            type = "bezier";
            points = [[0.65 0.05] [0.36 1]];
          }
        ];
      }
    ];

    animation = [
      {
        leaf = "windows";
        enabled = true;
        speed = 5;
        bezier = "easeOutQuint";
      }
      {
        leaf = "windowsOut";
        enabled = true;
        speed = 4;
        bezier = "easeOutQuint";
        style = "popin 80%";
      }
      {
        leaf = "border";
        enabled = true;
        speed = 8;
        bezier = "easeOutQuint";
      }
      {
        leaf = "borderangle";
        enabled = true;
        speed = 6;
        bezier = "easeOutQuint";
      }
      {
        leaf = "fade";
        enabled = true;
        speed = 4;
        bezier = "easeOutQuint";
      }
      {
        leaf = "workspaces";
        enabled = true;
        speed = 5;
        bezier = "easeOutQuint";
        style = "slidefade 20%";
      }
    ];
  };
}
