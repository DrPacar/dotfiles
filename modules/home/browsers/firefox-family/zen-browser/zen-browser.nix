{ inputs, pkgs, ... }: 
let
  zenSettings = import ./_settings.nix;
  extensions = import ../_extensions.nix {
    exclude = [ "{3c078156-979c-498b-8990-85f7987dd929}" ]; # Excludes Sidebery
  };
  searchSettings = import ../_searches.nix;
  bookmarkSettings = import ../_bookmarks.nix;
in
  {
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

  imports = [ inputs.zen-browser.homeModules.beta ];
  home.packages = with pkgs; [
    jq
    lz4
    lsof

    # --- Custom One-Command Zen Bootstrapper for NH ---
    (pkgs.writeShellScriptBin "zen-sync" ''
      echo "=== 1/4: Building structural foundation ==="
      rm -rf ~/.config/zen/**/*.backup ~/.config/zen/*.backup 2>/dev/null || true
      nh os switch

      echo "=== 2/4: First Launch ==="
      echo "Opening Zen for the 1st time..."
      echo "-> Close the browser normally"
      zen-beta &
      ZEN_PID=$!
      wait $ZEN_PID 2>/dev/null

      echo "=== 3/4: Second Launch ==="
      echo "Opening Zen for the 2nd time..."
      echo "-> Close the browser normally again"
      zen-beta &
      ZEN_PID=$!
      wait $ZEN_PID 2>/dev/null

      echo "=== 4/4: Injecting Containers, Workspaces, and Pins ==="
      rm -rf ~/.config/zen/**/*.backup ~/.config/zen/*.backup 2>/dev/null || true
      sudo systemctl restart home-manager-luka.service

      echo "=== Done! Zen is fully configured and injected. ==="
    '')
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
        "Uni" = {
          color = "purple";
          icon = "circle";
          id = 3;
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
        "Work" = {
          id = "e5f6a1b2-9012-34ab-cdef-5678901234ab";
          position = 200;
          icon = "💼";
          container = 2;
        };
        "Uni" = {
          id = "f6a1b2c3-0123-45ab-cdef-6789012345ab";
          position = 300;
          icon = "🎓";
          container = 3;
        };
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
        "Files" = {
          id = "55555555-5555-5555-5555-555555555555";
          url = "https://example.com/dummy-files";
          isEssential = true;
          position = 50;
        };

        # --- Private Pinned Tabs ---
        "YouTube" = {
          id = "eb7870a6-ca65-4d2b-9999-123456789012";
          url = "https://www.youtube.com";
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
        "Lichess" = {
          id = "77777777-7777-7777-7777-777777777777";
          url = "https://lichess.org";
          container = 1;
          workspace = "d4e5f6a1-8901-23ab-cdef-4567890123ab";
          position = 103;
        };

        # --- Work Pinned Tabs ---
        "GitHub Repos" = {
          id = "48e8a119-5a14-4826-9545-91c8e8dd3bf6";
          url = "https://github.com/DrPacar?tab=repositories";
          container = 2;
          workspace = "e5f6a1b2-9012-34ab-cdef-5678901234ab";
          position = 201;
        };
        "Gemini (Work)" = {
          id = "88888888-8888-8888-8888-888888888888";
          url = "https://gemini.google.com";
          container = 2;
          workspace = "e5f6a1b2-9012-34ab-cdef-5678901234ab";
          position = 202;
        };
        "Claude (Work)" = {
          id = "99999999-9999-9999-9999-999999999999";
          url = "https://claude.ai";
          container = 2;
          workspace = "e5f6a1b2-9012-34ab-cdef-5678901234ab";
          position = 203;
        };

        # --- Uni Pinned Tabs ---
        "Outlook" = {
          id = "aaaaaamm-aaaa-aaaa-aaaa-aaaaaaaaaaaa";
          url = "https://outlook.office.com/mail";
          container = 3;
          workspace = "f6a1b2c3-0123-45ab-cdef-6789012345ab";
          position = 301;
        };
        "TISS TU Wien" = {
          id = "c3d4e5f6-7890-12ab-cdef-3456789012ab";
          url = "https://tiss.tuwien.ac.at/";
          container = 3;
          workspace = "f6a1b2c3-0123-45ab-cdef-6789012345ab";
          position = 302;
        };
        "Gemini (Uni)" = {
          id = "bbbbbmmm-bbbb-bbbb-bbbb-bbbbbbbbbbbb";
          url = "https://gemini.google.com";
          container = 3;
          workspace = "f6a1b2c3-0123-45ab-cdef-6789012345ab";
          position = 303;
        };
      };
      
    };
  };
}
