{lib, ...}: let
  # Helper to associate a list of MIME types with a single desktop file
  assoc = mimes: app: lib.genAttrs mimes (_: app);

  # ============================================================================
  # Default Applications
  # ============================================================================
  apps = {
    browser = "zen-beta.desktop";
    fileManager = "org.gnome.Nautilus.desktop";
    office = "onlyoffice-desktopeditors.desktop";
    textEditor = "nvim.desktop";
    pdfViewer = "org.pwmt.zathura.desktop";
    imageViewer = "imv-dir.desktop";
    mediaPlayer = "mpv.desktop";
    mailClient = "thunderbird.desktop";
    discord = "discord.desktop";
    spotify = "spotify.desktop";
  };

  # ============================================================================
  # MIME Type Collections
  # ============================================================================

  # 1. Web & Links
  browserMimes = [
    "text/html"
    "text/xml"
    "application/xhtml+xml"
    "application/x-xpinstall"
    "x-scheme-handler/http"
    "x-scheme-handler/https"
    "x-scheme-handler/about"
    "x-scheme-handler/unknown"
  ];

  # 2. Directories (File Manager)
  directoryMimes = [
    "inode/directory"
  ];

  # 3. Office & Documents (OnlyOffice)
  officeMimes = [
    # Word Documents
    "application/msword"
    "application/vnd.openxmlformats-officedocument.wordprocessingml.document"
    "application/vnd.oasis.opendocument.text"
    "application/vnd.oasis.opendocument.text-template"
    "application/rtf"

    # Excel Spreadsheets
    "application/vnd.ms-excel"
    "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
    "application/vnd.oasis.opendocument.spreadsheet"
    "application/vnd.oasis.opendocument.spreadsheet-template"
    "text/csv"

    # PowerPoint Presentations
    "application/vnd.ms-powerpoint"
    "application/vnd.openxmlformats-officedocument.presentationml.presentation"
    "application/vnd.oasis.opendocument.presentation"
    "application/vnd.oasis.opendocument.presentation-template"
  ];

  # 4. Text & Code Files
  textMimes = [
    "text/plain"
    "text/markdown"
    "text/x-log"
    "text/x-shellscript"
    "application/json"
    "application/toml"
    "application/yaml"
    "text/yaml"
    "text/x-nix"
    "text/x-lua"
    "text/x-python"
    "text/x-c"
    "text/x-c++"
    "text/x-java-source"
    "text/x-rust"
  ];

  # 5. PDF & Documents (Zathura)
  pdfMimes = [
    "application/pdf"
    "application/x-pdf"
    "application/oxps"
    "application/vnd.comicbook+zip"
    "application/vnd.comicbook-rar"
    "application/x-cbz"
    "application/x-cbr"
    "application/x-cb7"
    "application/x-cbt"
    "application/postscript"
    "application/x-eps"
    "image/vnd.djvu"
    "image/vnd.djvu+multipage"
  ];

  # 6. Images (imv)
  imageMimes = [
    "image/png"
    "image/jpeg"
    "image/jpg"
    "image/pjpeg"
    "image/webp"
    "image/gif"
    "image/bmp"
    "image/x-bmp"
    "image/tiff"
    "image/tiff-fx"
    "image/svg+xml"
    "image/heif"
    "image/heic"
    "image/avif"
    "image/jxl"
    "image/qoi"
    "image/x-png"
    "image/x-farbfeld"
    "image/x-portable-anymap"
    "image/x-portable-bitmap"
    "image/x-portable-graymap"
    "image/x-portable-pixmap"
    "image/x-tga"
    "image/x-win-bitmap"
    "image/x-xbitmap"
    "image/x-xpixmap"
    "image/vnd.microsoft.icon"
    "image/x-ico"
    "image/x-icon"
  ];

  # 7. Video & Audio (mpv)
  mediaMimes = [
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

  # 8. E-Mail
  mailMimes = [
    "x-scheme-handler/mailto"
    "message/rfc822"
  ];

  # 9. App Protocols
  protocolHandlers = {
    "x-scheme-handler/discord" = apps.discord;
    "x-scheme-handler/spotify" = apps.spotify;
  };
in {
  xdg.mimeApps = {
    enable = true;

    defaultApplications = lib.mkMerge [
      (assoc browserMimes apps.browser)
      (assoc directoryMimes apps.fileManager)
      (assoc officeMimes apps.office)
      (assoc textMimes apps.textEditor)
      (assoc pdfMimes apps.pdfViewer)
      (assoc imageMimes apps.imageViewer)
      (assoc mediaMimes apps.mediaPlayer)
      (assoc mailMimes apps.mailClient)
      protocolHandlers
    ];
  };
}
