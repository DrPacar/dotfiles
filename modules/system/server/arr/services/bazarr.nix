{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (lib) mkOption mkIf types;
  cfg = config.server.arr;
  inherit (import ../_lib.nix) secretRef;

  bazarrUser = "bazarr";
in {
  options.server.arr.bazarr = {
    enable = mkOption {
      type = types.bool;
      default = true;
      description = "Enable Bazarr subtitle manager.";
    };

    port = mkOption {
      type = types.port;
      default = 6767;
      description = "Port for Bazarr web interface.";
    };

    subdomain = mkOption {
      type = types.str;
      default = "bazarr";
      description = "Subdomain name for Bazarr reverse proxy routing.";
    };
  };

  config = mkIf (cfg.enable && cfg.bazarr.enable) {
    assertions = [
      {
        assertion = config.sops.secrets ? arr_bazarr_api_key;
        message = "arr.bazarr: config.sops.secrets.arr_bazarr_api_key must be defined in your secrets file.";
      }
      {
        assertion = !cfg.sonarr.enable || config.sops.secrets ? arr_sonarr_api_key;
        message = "arr.bazarr: config.sops.secrets.arr_sonarr_api_key must be defined when Sonarr is enabled.";
      }
      {
        assertion = !cfg.radarr.enable || config.sops.secrets ? arr_radarr_api_key;
        message = "arr.bazarr: config.sops.secrets.arr_radarr_api_key must be defined when Radarr is enabled.";
      }
    ];

    # Ensure Bazarr writes subtitle files with group-writable permissions (rw-rw-r--)
    systemd.services.bazarr.serviceConfig.UMask = "0002";

    services.bazarr = {
      enable = true;
      user = bazarrUser;
      group = cfg.mediaGroup;
      openFirewall = false;

      settings = {
        general = {
          ip = cfg.network.bindAddress;
          port = cfg.bazarr.port;
          use_sonarr = cfg.sonarr.enable;
          use_radarr = cfg.radarr.enable;
          enabled_providers = [
            "animetosho"
            "embeddedsubtitles"
            "yifysubtitles"
            "subdl"
            "subsource"
          ];
          movie_default_enabled = true;
          movie_default_profile = 1;
          serie_default_enabled = true;
          serie_default_profile = 1;
        };
        auth = {
          apikey = secretRef config.sops.secrets.arr_bazarr_api_key.path;
        };
        sonarr = mkIf cfg.sonarr.enable {
          ip = cfg.network.localAddress;
          port = cfg.sonarr.port;
          apikey = secretRef config.sops.secrets.arr_sonarr_api_key.path;
          ssl = false;
          base_url = "";
        };
        radarr = mkIf cfg.radarr.enable {
          ip = cfg.network.localAddress;
          port = cfg.radarr.port;
          apikey = secretRef config.sops.secrets.arr_radarr_api_key.path;
          ssl = false;
          base_url = "";
        };
      };
    };

    # Automatically ensure default language profile (German & English) in Bazarr database
    systemd.services.bazarr-setup-profile = {
      description = "Ensure default language profiles in Bazarr database";
      before = ["bazarr.service"];
      wantedBy = ["multi-user.target"];

      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        User = bazarrUser;
        Group = cfg.mediaGroup;
        StateDirectory = "bazarr";
      };

      script = ''
        ${pkgs.python3}/bin/python3 -c "
        import sqlite3, json, os

        db_dir = '/var/lib/bazarr/db'
        db_path = os.path.join(db_dir, 'bazarr.db')
        os.makedirs(db_dir, exist_ok=True)

        conn = sqlite3.connect(db_path)
        conn.execute('''
            CREATE TABLE IF NOT EXISTS table_languages_profiles (
                profileId INTEGER PRIMARY KEY,
                cutoff INTEGER,
                originalFormat INTEGER,
                items TEXT NOT NULL,
                name TEXT NOT NULL,
                mustContain TEXT,
                mustNotContain TEXT,
                tag TEXT
            )
        ''')
        items = json.dumps([
            {'id': 1, 'language': 'de', 'hi': 'False', 'forced': 'False', 'audio_exclude': 'False', 'audio_only_include': 'False'},
            {'id': 2, 'language': 'en', 'hi': 'False', 'forced': 'False', 'audio_exclude': 'False', 'audio_only_include': 'False'}
        ])
        conn.execute('''
            INSERT OR REPLACE INTO table_languages_profiles 
            (profileId, name, items, mustContain, mustNotContain, originalFormat) 
            VALUES (1, 'Standard (Deutsch & Englisch)', ?, '[]', '[]', 0)
        ''', (items,))

        try:
            conn.execute(\"UPDATE table_settings_languages SET enabled = 1 WHERE code2 IN ('de', 'en')\")
        except sqlite3.OperationalError:
            pass

        conn.commit()
        conn.close()
        "
      '';
    };
  };
}
