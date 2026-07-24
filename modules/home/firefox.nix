{ pkgs, lib, config, ... }:
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

    policies = {
      ExtensionSettings = {
        "adguardadblocker@adguard.com" = {
          install_url = "https://addons.mozilla.org/firefox/downloads/latest/adguard-adblocker/latest.xpi";
          installation_mode = "force_installed";
        };
        "{22b0eca1-8c02-4c0d-a5d7-6604ddd9836e}" = {
          install_url = "https://addons.mozilla.org/firefox/downloads/latest/nicothin-space/latest.xpi";
          installation_mode = "force_installed";
        };
        "{446900e4-71c2-419f-a6a7-df9c091e268b}" = {
          install_url = "https://addons.mozilla.org/firefox/downloads/latest/bitwarden-password-manager/latest.xpi";
          installation_mode = "force_installed";
        };
        "{74145f27-f039-47ce-a470-a662b129930a}" = {
          install_url = "https://addons.mozilla.org/firefox/downloads/latest/clearurls/latest.xpi";
          installation_mode = "force_installed";
        };
        "{762f9885-5a13-4abd-9c77-433dcd38b8fd}" = {
          install_url = "https://addons.mozilla.org/firefox/downloads/latest/return-youtube-dislikes/latest.xpi";
          installation_mode = "force_installed";
        };
        "sponsorBlocker@ajay.app" = {
          install_url = "https://addons.mozilla.org/firefox/downloads/latest/sponsorblock/latest.xpi";
          installation_mode = "force_installed";
        };
        "addon@darkreader.org" = {
          install_url = "https://addons.mozilla.org/firefox/downloads/latest/darkreader/latest.xpi";
          installation_mode = "force_installed";
        };
        "{3c078156-979c-498b-8990-85f7987dd929}" = {
          install_url = "https://addons.mozilla.org/firefox/downloads/latest/sidebery/latest.xpi";
          installation_mode = "force_installed";
        };
        "{c2c003ee-bd69-42a2-b0e9-6f34222cb046}" = {
          install_url = "https://addons.mozilla.org/firefox/downloads/latest/auto-tab-discard/latest.xpi";
          installation_mode = "force_installed";
        };
        "{b86e4813-687a-43e6-ab65-0bde4ab75758}" = {
          install_url = "https://addons.mozilla.org/firefox/downloads/latest/localcdn-fork-of-decentraleyes/latest.xpi";
          installation_mode = "force_installed";
        };
        "{531906d3-e22f-4a6c-a102-8057b88a1a63}" = {
          install_url = "https://addons.mozilla.org/firefox/downloads/latest/single-file/latest.xpi";
          installation_mode = "force_installed";
        };
      };
    };

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

      settings = {
        "signon.rememberSignons" = false;
        "signon.autofillForms" = false;
        "signon.generation.enabled" = false;
        "extensions.formautofill.creditCards.enabled" = false;
        "extensions.formautofill.addresses.enabled" = false;
        "browser.shell.checkDefaultBrowser" = false;
        "browser.translations.automaticallyPopup" = false;
        "browser.translations.enable" = false;
        "toolkit.legacyUserProfileCustomizations.stylesheets" = true;
        "media.gmp-widevinecdm.enabled" = true;
        "media.eme.enabled" = true;
        "toolkit.telemetry.enabled" = false;
        "datareporting.healthreport.uploadEnabled" = false;
        "browser.newtabpage.activity-stream.feeds.telemetry" = false;
        "browser.newtabpage.activity-stream.showSponsored" = false;
        "browser.newtabpage.activity-stream.showSponsoredTopSites" = false;
        "extensions.pocket.enabled" = false;
        "browser.contentblocking.category" = "strict";
        "browser.tabs.warnOnClose" = false;
        "full-screen-api.warning.timeout" = 0;
        "sidebar.position_start" = false;
        "browser.tabs.inTitlebar" = 1;

        # Devtools
        "devtools.jsonview.enabled" = true;
        "devtools.netmonitor.persistlog" = true;
        "devtools.cache.disabled" = true;

        # Top Sites
        "browser.newtabpage.activity-stream.topSitesRows" = 2;
        "browser.newtabpage.activity-stream.default.sites" = "";

        "browser.newtabpage.pinned" = builtins.toJSON [
          { url = "https://github.com/DrPacar?tab=repositories"; label = "GitHub"; }
          { url = "https://claude.ai"; label = "Claude"; }
          { url = "https://gemini.google.com"; label = "Gemini"; }
          { url = "https://chatgpt.com"; label = "ChatGPT"; }
          { url = "https://oesterreich.gv.at"; label = "ID"; }
          { url = "https://finanzonline.bmf.gv.at"; label = "FinanzOnline"; }
          { url = "https://www.e-brief.at/fe/deliveries"; label = "Post-Briefkasten"; }
          { url = "https://web.whatsapp.com/"; label = "WhatsApp"; }
          { url = "https://mail.google.com/"; label = "Gmail"; }
          { url = "https://www.reddit.com"; label = "Reddit"; }
          { url = "https://www.netflix.com"; label = "Netflix"; }
          { url = "https://youtube.com"; label = "Youtube"; }
          { url = "https://twitch.tv"; label = "Twitch"; }
          { url = "https://www.amazon.de"; label = "Amazon"; }
          { url = "https://dash.cloudflare.com"; label = "Cloudflare"; }
          { url = "https://www.chess.com/play/online"; label = "Chess.com"; }
          { url = "https://lichess.org/study"; label = "Lichess Studies"; }
          { url = "https://chesstempo.com"; label = "Chesstempo"; }
          { url = "https://www.tuwien.at/"; label = "TU Wien"; }
        ];
      };

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
