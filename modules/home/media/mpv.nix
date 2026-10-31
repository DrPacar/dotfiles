{
  lib,
  pkgs,
  ...
}: let
  mediaMimeTypes = [
    # Video
    "video/mp4"
    "video/mkv"
    "video/x-matroska"
    "video/webm"
    "video/avi"
    "video/x-msvideo"
    "video/quicktime"
    "video/x-flv"
    "video/mpeg"
    "video/ogg"
    # Audio
    "audio/mpeg"
    "audio/mp3"
    "audio/flac"
    "audio/wav"
    "audio/x-wav"
    "audio/ogg"
    "audio/aac"
    "audio/m4a"
    "audio/opus"
  ];
  mimeAssociations = lib.genAttrs mediaMimeTypes (_: "mpv.desktop");
in {
  programs.mpv = {
    enable = true;

    scripts = with pkgs.mpvScripts; [
      mpris # Media keys / Noctalia integration via playerctl
      thumbfast # Fast seekbar thumbnail preview
    ];

    config = {
      # Quality & Hardware acceleration
      hwdec = "auto-safe";
      vo = "gpu";
      profile = "gpu-hq";

      # Window behavior
      keep-open = "yes";
      autofit-larger = "80%x80%";

      # Audio
      volume = 100;
      volume-max = 150;

      # Subtitles
      sub-auto = "fuzzy";
      slang = "de,deu,ger,en,eng";
      alang = "de,deu,ger,en,eng,ja,jpn";

      # UI / OSD (TokyoNight styling)
      osd-bar = false;
      osd-font = "JetBrainsMono Nerd Font";
      osd-font-size = 24;
      osd-color = "#c0caf5";
      osd-border-color = "#1a1b26";
    };
  };

  xdg.mimeApps = {
    enable = true;
    defaultApplications = mimeAssociations;
  };
}
