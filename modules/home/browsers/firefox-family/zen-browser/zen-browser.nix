{
  inputs,
  pkgs,
  config,
  lib,
  ...
}: let
  zenSettings = import ./_settings.nix;
  extensions = import ../_extensions.nix {
    exclude = ["{3c078156-979c-498b-8990-85f7987dd929}"]; # Excludes Sidebery
  };
  searchSettings = import ../_searches.nix;
  bookmarkSettings = import ../_bookmarks.nix;
in {
  xdg.mimeApps = {
    enable = true;
    defaultApplications = {
      "text/html" = "zen-beta.desktop";
      "x-scheme-handler/http" = "zen-beta.desktop";
      "x-scheme-handler/https" = "zen-beta.desktop";
      "x-scheme-handler/about" = "zen-beta.desktop";
      "x-scheme-handler/unknown" = "zen-beta.desktop";
    };
  };

  imports = [inputs.zen-browser.homeModules.beta];
  home.packages = with pkgs; [
    jq
    lz4
    lsof
  ];

  programs.zen-browser = {
    enable = true;
    policies = extensions;

    profiles.default = {
      id = 0;
      name = "default";
      path = "default";
      isDefault = true;

      settings = zenSettings;
      search = searchSettings;
      bookmarks = bookmarkSettings;
      userChrome = builtins.readFile ./userChrome.css;
      userContent = builtins.readFile ./userContent.css;

      mods = [
        "253a3a74-0cc4-47b7-8b82-996a64f030d5" # Floating History
        "906c6915-5677-48ff-9bfc-096a02a72379" # Floating Status Bar
        "a6335949-4465-4b71-926c-4a52d34bc9c0" # Better Find Bar
        "e122b5d9-d385-4bf8-9971-e137809097d0" # No Top Sites
        "f7c71d9a-bce2-420f-ae44-a64bd92975ab" # Better Unloaded Tabs
        "fd24f832-a2e6-4ce9-8b19-7aa888eb7f8e" # Quietify
        "d8b79d4a-6cba-4495-9ff6-d6d30b0e94fe" # Better Active Tab
        "58649066-2b6f-4a5b-af6d-c3d21d16fc00" # Private Mode Highlighting
      ];

      # --- Multi-Account Containers ---
      containersForce = true;
      containers = {
        "Private" = {
          color = "pink";
          icon = "fingerprint";
          id = 1;
        };
        "Work" = {
          color = "turquoise";
          icon = "briefcase";
          id = 2;
        };
        "Education" = {
          color = "purple";
          icon = "circle";
          id = 3;
        };
        "Chess" = {
          color = "green";
          icon = "circle";
          id = 4;
        };
      };

      # --- Workspaces / Spaces ---
      spacesForce = true;
      spaces = {
        "Private" = {
          id = "d4e5f6a1-8901-23ab-cdef-4567890123ab";
          position = 100;
          icon = "🏠";
          container = 1;
        };
        "Education" = {
          id = "f6a1b2c3-0123-45ab-cdef-6789012345ab";
          position = 200;
          icon = "🎓";
          container = 2;
          routes = {
            tuwien = {
              reference = "tuwien.ac.at";
              matchType = "contains";
            };
          };
        };
        "Work" = {
          id = "e5f6a1b2-9012-34ab-cdef-5678901234ab";
          position = 300;
          icon = "💻";
          container = 3;
        };
        "Chess" = {
          id = "a1b2c3d4-1234-56ab-cdef-7890123456ab";
          position = 400;
          icon = "♟️";
          container = 4;
          routes = {
            chess-com = {
              reference = "chess.com";
              matchType = "contains";
            };
            lichess = {
              reference = "lichess.org";
              matchType = "contains";
            };
          };
        };
      };

      # --- Space Routing ---
      spaceRouting = {
        force = true;
        defaultExternalRoute = "most-recent-space";
      };

      # --- Pinned Tabs ---
      pinsForce = true;
      pinsForceAction = "remove";
      pins = {
        # --- Global Pins (Essentials) ---
        "WhatsApp" = {
          id = "11111111-1111-1111-1111-111111111111";
          url = "https://web.whatsapp.com";
          isEssential = true;
          position = 10;
        };
        "Gmail" = {
          id = "22222222-2222-2222-2222-222222222222";
          url = "https://mail.google.com";
          isEssential = true;
          position = 20;
        };
        "Notion" = {
          id = "33333333-3333-3333-3333-333333333333";
          url = "https://www.notion.so";
          isEssential = true;
          position = 30;
        };
        "Notion Calendar" = {
          id = "44444444-4444-4444-4444-444444444444";
          url = "https://calendar.notion.so";
          isEssential = true;
          position = 40;
        };
        "Dashboard" = {
          id = "55555555-5555-5555-5555-555555555555";
          url = "https://lukpac.dev";
          isEssential = true;
          position = 50;
        };

        # --- Private Pinned Tabs ---
        "Claude (Private)" = {
          id = "eb7870a6-ca65-4d2b-9999-123456aaa012";
          url = "https://claude.ai";
          container = 1;
          workspace = "d4e5f6a1-8901-23ab-cdef-4567890123ab";
          position = 101;
        };
        "Gemini (Private)" = {
          id = "b2c3d4e5-6789-01ab-cdef-2345678901ab";
          url = "https://gemini.google.com";
          container = 1;
          workspace = "d4e5f6a1-8901-23ab-cdef-4567890123ab";
          position = 102;
        };
        "Seerr" = {
          id = "eb7870a6-ca65-4d2b-9999-123456789016";
          url = "https://seerr.media.lukpac.dev";
          container = 1;
          workspace = "d4e5f6a1-8901-23ab-cdef-4567890123ab";
          position = 103;
        };
        "Jellyfin" = {
          id = "eb7870a6-ca65-4d2b-9999-123456789017";
          url = "https://jellyfin.media.lukpac.dev";
          container = 1;
          workspace = "d4e5f6a1-8901-23ab-cdef-4567890123ab";
          position = 103;
        };

        # --- Education Pinned Tabs ---
        "Claude (Education)" = {
          id = "bbbbbmmm-bbbb-bbbb-bbbb-bbbbbbbbbbbm";
          url = "https://claude.ai";
          container = 2;
          workspace = "f6a1b2c3-0123-45ab-cdef-6789012345ab";
          position = 201;
        };
        "Gemini (Education)" = {
          id = "bbbbbmmm-bbbb-bbbb-bbbb-bbbbbbbbbbbb";
          url = "https://gemini.google.com";
          container = 2;
          workspace = "f6a1b2c3-0123-45ab-cdef-6789012345ab";
          position = 202;
        };
        "Tiss" = {
          id = "c3d4e5f6-7890-12ab-cdef-3456789012ab";
          url = "https://tiss.tuwien.ac.at/";
          container = 2;
          workspace = "f6a1b2c3-0123-45ab-cdef-6789012345ab";
          position = 203;
        };
        "Tuwel" = {
          id = "c3d4e5f6-7890-12ab-cdef-3456789012ac";
          url = "https://tuwel.tuwien.ac.at/my";
          container = 2;
          workspace = "f6a1b2c3-0123-45ab-cdef-6789012345ab";
          position = 204;
        };

        # --- Work Pinned Tabs ---
        "Claude (Work)" = {
          id = "99999999-9999-9999-9999-999999999999";
          url = "https://claude.ai";
          container = 3;
          workspace = "e5f6a1b2-9012-34ab-cdef-5678901234ab";
          position = 301;
        };
        "Gemini (Work)" = {
          id = "88888888-8888-8888-8888-888888888888";
          url = "https://gemini.google.com";
          container = 3;
          workspace = "e5f6a1b2-9012-34ab-cdef-5678901234ab";
          position = 302;
        };
        "GitHub Repos" = {
          id = "48e8a119-5a14-4826-9545-91c8e8dd3bf6";
          url = "https://github.com/DrPacar?tab=repositories";
          container = 3;
          workspace = "e5f6a1b2-9012-34ab-cdef-5678901234ab";
          position = 303;
        };

        # --- Chess Pinned Tabs ---
        "Claude (Chess)" = {
          id = "cc000001-cc00-cc00-cc00-cc0000000001";
          url = "https://claude.ai";
          container = 4;
          workspace = "a1b2c3d4-1234-56ab-cdef-7890123456ab";
          position = 401;
        };
        "Gemini (Chess)" = {
          id = "cc000001-cc00-cc00-cc00-cc0000000002";
          url = "https://gemini.google.com";
          container = 4;
          workspace = "a1b2c3d4-1234-56ab-cdef-7890123456ab";
          position = 402;
        };
        "Chess.com Library" = {
          id = "cc000001-cc00-cc00-cc00-cc0000000003";
          url = "https://www.chess.com/library";
          container = 4;
          workspace = "a1b2c3d4-1234-56ab-cdef-7890123456ab";
          position = 403;
        };
        "Chess.com Events" = {
          id = "cc000001-cc00-cc00-cc00-cc0000000004";
          url = "https://www.chess.com/events";
          container = 4;
          workspace = "a1b2c3d4-1234-56ab-cdef-7890123456ab";
          position = 404;
        };
        "Lichess" = {
          id = "cc000002-cc00-cc00-cc00-cc0000000005";
          url = "https://lichess.org";
          container = 4;
          workspace = "a1b2c3d4-1234-56ab-cdef-7890123456ab";
          position = 405;
        };
      };

      # --- Keyboard Shortcuts ---
      keyboardShortcuts = [
        {
          id = "key_selectTab1";
          disabled = true;
        }
        {
          id = "key_selectTab2";
          disabled = true;
        }
        {
          id = "key_selectTab3";
          disabled = true;
        }
        {
          id = "key_selectTab4";
          disabled = true;
        }

        {
          id = "zen-workspace-switch-1";
          key = "1";
          modifiers = {
            control = false;
            alt = true;
            shift = false;
            meta = false;
            accel = false;
          };
        }
        {
          id = "zen-workspace-switch-2";
          key = "2";
          modifiers = {
            control = false;
            alt = true;
            shift = false;
            meta = false;
            accel = false;
          };
        }
        {
          id = "zen-workspace-switch-3";
          key = "3";
          modifiers = {
            control = false;
            alt = true;
            shift = false;
            meta = false;
            accel = false;
          };
        }
        {
          id = "zen-workspace-switch-4";
          key = "4";
          modifiers = {
            control = false;
            alt = true;
            shift = false;
            meta = false;
            accel = false;
          };
        }
      ];

      # --- Extension Toolbar Placement ---
      extensionButtons = {
        "nav-bar" = [
          "{446900e4-71c2-419f-a6a7-df9c091e268b}" # Bitwarden
        ];
        "unified-extensions-area" = [
          "adguardadblocker@adguard.com"
          "sponsorBlocker@ajay.app"
          "{74145f27-f039-47ce-a470-a662b129930a}" # ClearURLs
          "{762f9885-5a13-4abd-9c77-433dcd38b8fd}" # Return YouTube Dislikes
          "{c2c003ee-bd69-42a2-b0e9-6f34222cb046}" # Auto Tab Discard
          "{b86e4813-687a-43e6-ab65-0bde4ab75758}" # LocalCDN
          "{531906d3-e22f-4a6c-a102-8057b88a1a63}" # SingleFile
          "{22b0eca1-8c02-4c0d-a5d7-6604ddd9836e}" # Nicothin Space
        ];
      };
    };

    # Declaratively enforce the sidebar top buttons placement:
    # 1. Toggle Compact Mode
    # 2. Show Tabs From Other Devices (sync-button)
    # 3. Print this Page... (print-button)
    activationFragments.default = [
      {
        priority = 200;
        requiresLock = true;
        skipSubject = "sidebar top buttons";
        text = ''
                    PREFS_FILE="${config.programs.zen-browser.profilesPath}/default/prefs.js"
                    if [ -f "$PREFS_FILE" ]; then
                      ${pkgs.python3}/bin/python3 - << 'EOF'
          import json

          path = "${config.programs.zen-browser.profilesPath}/default/prefs.js"
          try:
              with open(path, "r") as f:
                  lines = f.readlines()

              new_lines = []
              modified = False
              for line in lines:
                  if line.startswith('user_pref("browser.uiCustomization.state", '):
                      prefix = 'user_pref("browser.uiCustomization.state", '
                      suffix = ');\n'
                      val_str = line[len(prefix):-len(suffix)]
                      raw_json = json.loads(val_str)
                      state = json.loads(raw_json)
                      target = ["zen-toggle-compact-mode", "sync-button", "print-button"]
                      if state.get("placements", {}).get("zen-sidebar-top-buttons") != target:
                          state.setdefault("placements", {})["zen-sidebar-top-buttons"] = target
                          new_val_str = json.dumps(json.dumps(state))
                          new_lines.append(f"{prefix}{new_val_str}{suffix}")
                          modified = True
                          continue
                  new_lines.append(line)

              if modified:
                  with open(path, "w") as f:
                      f.writelines(new_lines)
          except Exception:
              pass
          EOF
                    fi
        '';
      }
    ];
  };
}
