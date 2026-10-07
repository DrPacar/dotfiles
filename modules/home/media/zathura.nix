{lib, ...}: let
  pdfMimeTypes = [
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
  mimeAssociations = lib.genAttrs pdfMimeTypes (_: "org.pwmt.zathura.desktop");
in {
  programs.zathura = {
    enable = true;

    options = {
      # Font & Layout
      font = "JetBrainsMono Nerd Font 11";
      selection-clipboard = "clipboard";
      adjust-open = "best-fit";
      pages-per-row = 1;
      scroll-page-aware = true;
      scroll-step = 50;

      # Window & Statusbar
      window-title-basename = true;
      statusbar-basename = true;
      statusbar-home-tilde = true;
      statusbar-h-padding = 10;
      statusbar-v-padding = 6;
      page-h-padding = 6;
      page-v-padding = 6;
      render-loading = true;

      # Tokyo Night Color Scheme
      default-bg = "#1a1b26";
      default-fg = "#c0caf5";

      statusbar-bg = "#16161e";
      statusbar-fg = "#c0caf5";

      inputbar-bg = "#16161e";
      inputbar-fg = "#c0caf5";

      notification-bg = "#16161e";
      notification-fg = "#c0caf5";
      notification-error-bg = "#f7768e";
      notification-error-fg = "#16161e";
      notification-warning-bg = "#e0af68";
      notification-warning-fg = "#16161e";

      highlight-color = "rgba(224, 175, 104, 0.5)";
      highlight-active-color = "rgba(122, 162, 247, 0.5)";
      highlight-fg = "#16161e";

      completion-bg = "#16161e";
      completion-fg = "#c0caf5";
      completion-group-bg = "#16161e";
      completion-group-fg = "#7aa2f7";
      completion-highlight-bg = "#7aa2f7";
      completion-highlight-fg = "#16161e";

      index-bg = "#1a1b26";
      index-fg = "#c0caf5";
      index-active-bg = "#24283b";
      index-active-fg = "#7aa2f7";

      render-loading-bg = "#1a1b26";
      render-loading-fg = "#c0caf5";

      # Recolor (Dark Mode reading toggle with 'r')
      recolor = false;
      recolor-keephue = true;
      recolor-reverse-video = false;
      recolor-lightcolor = "#1a1b26";
      recolor-darkcolor = "#c0caf5";
    };

    mappings = {
      "u" = "scroll half-up";
      "d" = "scroll half-down";
      "D" = "toggle_page_mode";
      "r" = "recolor";
      "R" = "reload";
    };
  };

  xdg.mimeApps = {
    enable = true;
    defaultApplications = mimeAssociations;
  };
}
