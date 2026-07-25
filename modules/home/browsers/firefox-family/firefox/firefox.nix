{ pkgs, lib, config, ... }:
let
  firefoxSettings = import ./_settings.nix;
  extensions = import ../_extensions.nix {};
  searchSettings = import ../_searches.nix;
  bookmarkSettings = import ../_bookmarks.nix;
in
{
  xdg.mimeApps = {
    enable = true;
    defaultApplications = {
      "text/html" = "firefox.desktop";
      "x-scheme-handler/http" = "firefox.desktop";
      "x-scheme-handler/https" = "firefox.desktop";
      "x-scheme-handler/about" = "firefox.desktop";
      "x-scheme-handler/unknown" = "firefox.desktop";
    };
  };

  programs.firefox = {
    enable = true;
    configPath = "${config.xdg.configHome}/mozilla/firefox";

    policies = extensions;

    profiles.default = {
      id = 0;
      name = "default";
      isDefault = true; 

      settings = firefoxSettings;
      search = searchSettings;
      bookmarks = bookmarkSettings;

      userChrome = ''
        /* Die Tab-Leiste transparent machen und Buttons erhalten */
        #TabsToolbar {
          visibility: visible !important;
          background-color: transparent !important;
          -moz-window-dragging: drag !important;
        }

        /* Nur die Tabs darin ausblenden */
        #TabsToolbar .tabbrowser-tab,
        #TabsToolbar #alltabs-button,
        #TabsToolbar #new-tab-button {
          display: none !important;
        }

        #TabsToolbar .titlebar-spacer {
          display: none !important;
        }

        #PanelUI-button {
          margin-left: auto !important;
        }
      ''; 
    };
  };
}
