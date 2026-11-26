{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (lib) mkIf;
  cfg = config.server.arr;
  inherit (import ../../_lib.nix) secretRef;

  bazarrUser = "bazarr";

  commonOpenSubtitles = {
    username = secretRef config.sops.secrets.arr_opensubtitles_username.path;
    password = secretRef config.sops.secrets.arr_opensubtitles_password.path;
    use_hash = true;
    include_ai_translated = false;
    include_machine_translated = false;
  };

  commonSubsync = {
    use_subsync = cfg.bazarr.subsync.enable;
    auto_use_original_language = cfg.bazarr.subsync.autoUseOriginalLanguage;
    use_original_language = cfg.bazarr.subsync.useOriginalLanguage;
    gss = cfg.bazarr.subsync.gss;
    no_fix_framerate = cfg.bazarr.subsync.noFixFramerate;
    max_offset_seconds = cfg.bazarr.subsync.maxOffsetSeconds;
  };
in {
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
      {
        assertion = !cfg.jellyfin.enable || config.sops.secrets ? arr_jellyfin_api_key;
        message = "arr.bazarr: config.sops.secrets.arr_jellyfin_api_key must be defined when Jellyfin is enabled.";
      }
      {
        assertion = !cfg.bazarr.enable || config.sops.secrets ? arr_opensubtitles_username;
        message = "arr.bazarr: config.sops.secrets.arr_opensubtitles_username must be defined in your secrets file.";
      }
      {
        assertion = !cfg.bazarr.enable || config.sops.secrets ? arr_opensubtitles_password;
        message = "arr.bazarr: config.sops.secrets.arr_opensubtitles_password must be defined in your secrets file.";
      }
    ];

    # Subtitle file permissions, dynamic Jellyfin library resolution & systemd hardening
    systemd.services = let
      resolveJellyfinLibs = pkgs.writeShellScript "bazarr-resolve-jellyfin-libs" ''
        set -euo pipefail
        mkdir -p /run/bazarr-sync
        ENV_FILE="/run/bazarr-sync/jellyfin-libs.env"
        rm -f "$ENV_FILE"
        KEY_FILE="${config.sops.secrets.arr_jellyfin_api_key.path}"
        URL="http://${cfg.network.localAddress}:${toString cfg.jellyfin.port}"
        if [ ! -f "$KEY_FILE" ]; then
          exit 0
        fi
        TOKEN=$(tr -d '\n\r' < "$KEY_FILE")
        JSON=""
        for _ in $(seq 1 10); do
          if JSON=$(${pkgs.curl}/bin/curl -sf --max-time 3 -H "X-Emby-Token: $TOKEN" "$URL/Library/VirtualFolders" 2>/dev/null); then
            break
          fi
          sleep 1
        done
        if [ -z "$JSON" ]; then
          exit 0
        fi
        ${pkgs.python3}/bin/python3 - "$JSON" "$ENV_FILE" << 'PY'
        import json, sys
        folders = json.loads(sys.argv[1])
        env_path = sys.argv[2]
        by_name = {f.get("Name"): f.get("ItemId") for f in folders if f.get("Name") and f.get("ItemId")}
        movie_names = ${builtins.toJSON cfg.bazarr.jellyfinMovieLibraries}
        series_names = ${builtins.toJSON cfg.bazarr.jellyfinSeriesLibraries}
        movie_ids = [by_name[n] for n in movie_names if n in by_name]
        series_ids = [by_name[n] for n in series_names if n in by_name]
        lines = []
        if movie_ids:
            lines.append(f"DYNACONF_jellyfin__movie_library_ids=@json {json.dumps(movie_ids)}")
        if series_ids:
            lines.append(f"DYNACONF_jellyfin__series_library_ids=@json {json.dumps(series_ids)}")
        if lines:
            with open(env_path, "w", encoding="utf-8") as fh:
                fh.write("\n".join(lines) + "\n")
        PY
        if [ -f "$ENV_FILE" ]; then
          chown root:${cfg.mediaGroup} "$ENV_FILE"
          chmod 0640 "$ENV_FILE"
        fi
      '';
    in {
      bazarr-jellyfin-sync = lib.mkIf cfg.jellyfin.enable {
        description = "Resolve Jellyfin library IDs for Bazarr";
        after = ["jellyfin.service"];
        wants = ["jellyfin.service"];
        before = ["bazarr.service"];
        wantedBy = ["bazarr.service"];
        serviceConfig = {
          Type = "oneshot";
          Slice = lib.mkIf cfg.resources.enable "arr.slice";
          ExecStart = resolveJellyfinLibs;
        };
      };

      bazarr = {
        after = lib.optional cfg.jellyfin.enable "bazarr-jellyfin-sync.service";
        wants = lib.optional cfg.jellyfin.enable "bazarr-jellyfin-sync.service";
        serviceConfig = {
          UMask = "0002"; # rw-rw-r-- (group-writable for media group)
          Slice = "arr.slice";
          MemoryHigh = "1G";
          MemoryMax = "1.5G";
          Restart = "on-failure";
          RestartSec = 15;
          EnvironmentFile = lib.optional cfg.jellyfin.enable "-/run/bazarr-sync/jellyfin-libs.env";
        };
      };
    };

    sops.secrets.arr_jellyfin_api_key.restartUnits = mkIf cfg.jellyfin.enable [
      "bazarr.service"
    ];

    # =========================================================================
    # Standard Bazarr Instance (Port 6767) - TV Shows & Movies
    # =========================================================================
    services.bazarr = {
      enable = true;
      user = bazarrUser;
      group = cfg.mediaGroup;
      openFirewall = false;

      settings = {
        general = {
          ip = cfg.network.bindAddress;
          port = cfg.bazarr.port;
          instance_name = "Bazarr";
          use_sonarr = cfg.sonarr.enable;
          use_radarr = cfg.radarr.enable;
          use_jellyfin = cfg.jellyfin.enable;
          enabled_providers = cfg.bazarr.providers;
          movie_default_enabled = true;
          movie_default_profile = 1;
          serie_default_enabled = true;
          serie_default_profile = 1;

          # Optimized subtitle filesystem handling & encoding
          chmod = "0664";
          chmod_enabled = true;
          subfolder = "current";
          utf8_encode = true;
          adaptive_searching = true;
          use_embedded_subs = true;
          embedded_subtitles_parser = "ffprobe";
          parse_embedded_audio_track = true;
          upgrade_subs = true;
          upgrade_frequency = 12;
          days_to_upgrade_subs = 7;
          minimum_score = 90;
          minimum_score_movie = 70;
        };

        opensubtitlescom = commonOpenSubtitles;
        subsync = commonSubsync;

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

        jellyfin = mkIf cfg.jellyfin.enable {
          ip = cfg.network.localAddress;
          port = cfg.jellyfin.port;
          ssl = false;
          url = "http://${cfg.network.localAddress}:${toString cfg.jellyfin.port}";
          apikey = secretRef config.sops.secrets.arr_jellyfin_api_key.path;
          update_movie_library = true;
          update_series_library = true;
          movie_library = cfg.bazarr.jellyfinMovieLibraries;
          series_library = cfg.bazarr.jellyfinSeriesLibraries;
          refresh_method = "immediate";
        };
      };
    };
  };
}
