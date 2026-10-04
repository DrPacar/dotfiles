{lib, ...}: let
  imageMimeTypes = [
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
  mimeAssociations = lib.genAttrs imageMimeTypes (_: "imv-dir.desktop");
in {
  programs.imv.enable = true;

  xdg.mimeApps = {
    enable = true;
    defaultApplications = mimeAssociations;
  };
}
