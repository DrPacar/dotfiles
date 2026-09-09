{pkgs, ...}: {
  gtk = {
    enable = true;
    theme = {
      name = "adw-gtk3-dark";
      package = pkgs.adw-gtk3;
    };
    gtk4.theme = null;
    iconTheme = {
      name = "Papirus-Dark";
      package = pkgs.papirus-icon-theme;
    };
    cursorTheme = {
      name = "Bibata-Modern-Classic";
      package = pkgs.bibata-cursors;
      size = 24;
    };
    gtk3.extraCss = ''
      @define-color accent_color #7aa2f7;
      @define-color accent_bg_color #7aa2f7;
      @define-color accent_fg_color #1a1b26;
    '';
    gtk4.extraCss = ''
      @define-color accent_color #7aa2f7;
      @define-color accent_bg_color #7aa2f7;
      @define-color accent_fg_color #1a1b26;
    '';
  };

  qt = {
    enable = true;
    platformTheme.name = "gtk3";
    style.name = "adwaita-dark";
  };

  home.pointerCursor = {
    enable = true;
    gtk.enable = true;
    x11.enable = true;
    hyprcursor.enable = true;
    package = pkgs.bibata-cursors;
    name = "Bibata-Modern-Classic";
    size = 24;
  };

  xdg.portal = {
    enable = true;
    config.common.default = "*";
  };
}
