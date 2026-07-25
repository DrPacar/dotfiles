{ pkgs, lib, config, ... }:
let
  firefoxSettings = import ./_settings.nix;
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

    policies = import ../_extensions.nix {};

    profiles.default = {
      id = 0;
      name = "default";
      isDefault = true;

      search = {
        default = "google";
        force = true;
        engines = {
          "Nix Packages" = {
            urls = [{
              template = "https://search.nixos.org/packages";
              params = [
                { name = "type"; value = "packages"; }
                { name = "query"; value = "{searchTerms}"; }
              ];
            }];
            definedAliases = [ "@np" ];
          };
          "NixOS Options" = {
            urls = [{
              template = "https://search.nixos.org/options";
              params = [
                { name = "type"; value = "options"; }
                { name = "query"; value = "{searchTerms}"; }
              ];
            }];
            definedAliases = [ "@no" ];
          };
        };
      };

      settings = firefoxSettings;
      
      bookmarks = [
        {
          name = "toolbar";
          toolbar = true;
          bookmarks = [
            {
              name = "AI Tools";
              bookmarks = [
                { name = "Claude"; url = "https://claude.ai/"; }
                { name = "Gemini"; url = "https://gemini.google.com/"; }
                { name = "ChatGPT"; url = "https://chatgpt.com/"; }
              ];
            }
            { name = "GitHub Repos"; url = "https://github.com/DrPacar?tab=repositories"; }
            { name = "YouTube"; url = "https://www.youtube.com/"; }
            { name = "Gmail"; url = "https://mail.google.com/"; }
            { name = "TU Wien TISS"; url = "https://tiss.tuwien.ac.at/"; }
          ];
        }
      ];
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
