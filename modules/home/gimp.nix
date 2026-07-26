{ pkgs, ... }: {
  home.packages = with pkgs; [
    (gimp-with-plugins.override {
      plugins = with gimpPlugins; [
        gmic
        resynthesizer
      ];
    })
  ];

  dconf.settings = {
    "org/gnome/desktop/sound" = {
      event-sounds = false;
    };
  };
}
