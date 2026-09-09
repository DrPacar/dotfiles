{pkgs, ...}: {
  programs.ghostty = {
    enable = true;
    settings = {
      theme = "TokyoNight";
      font-family = "JetBrainsMono Nerd Font";
      font-size = 13;
      window-padding-x = 12;
      window-padding-y = 10;
      window-decoration = false;
      background-opacity = 0.92;
      background-blur-radius = 20;
      cursor-style = "block";
      cursor-style-blink = false;
    };
  };
}
