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

  mkDynaconfEnv = prefix: attrs:
    lib.foldl' lib.mergeAttrs {} (
      lib.mapAttrsToList (
        name: value: let
          key =
            if prefix == ""
            then name
            else "${prefix}__${name}";
        in
          if lib.isAttrs value && !lib.isDerivation value
          then mkDynaconfEnv key value
          else {"DYNACONF_${key}" = "@json ${lib.toJSON value}";}
      )
      attrs
    );

  commonOpenSubtitles = {
    username = secretRef config.sops.secrets.arr_opensubtitles_username.path;
    password = secretRef config.sops.secrets.arr_opensubtitles_password.path;
    use_hash = true;
    include_ai_translated = false;
    include_machine_translated = false;
  };

  commonSubsync = {
    use_subsync = true;
    auto_use_original_language = true;
    use_original_language = true;
    gss = true;
    no_fix_framerate = true;
  };

  animeEnabled = cfg.bazarr.anime.enable && cfg.sonarr.anime.enable;

  animeSettings =
    {
      analytics.enabled = false;
      general = {
        ip = cfg.network.bindAddress;
        port = cfg.bazarr.anime.port;
        instance_name = "Bazarr Anime";
        use_sonarr = true;
        use_radarr = false;
        use_jellyfin = cfg.jellyfin.enable;
        enabled_providers = [
          "animetosho"
          "embeddedsubtitles"
          "opensubtitlescom"
        ];
        movie_default_enabled = false;
        serie_default_enabled = true;
        serie_default_profile = 1;
        auto_update = false;
      };
      opensubtitlescom = commonOpenSubtitles;
      subsync = commonSubsync;
      sonarr = {
        ip = cfg.network.localAddress;
        port = cfg.sonarr.anime.port;
        ssl = false;
        base_url = "";
      };
    }
    // lib.optionalAttrs cfg.jellyfin.enable {
      jellyfin = {
        ip = cfg.network.localAddress;
        port = cfg.jellyfin.port;
        ssl = false;
        url = "http://${cfg.network.localAddress}:${toString cfg.jellyfin.port}";
        update_movie_library = false;
        update_series_library = true;
        movie_library = [];
        movie_library_ids = [];
        series_library = ["Anime"];
        series_library_ids = ["0c41907140d802bb58430fed7e2cd79e"];
        refresh_method = "immediate";
      };
    };

  animeEnv = mkDynaconfEnv "" animeSettings;
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

    anime = {
      enable = mkOption {
        type = types.bool;
        default = cfg.sonarr.anime.enable;
        description = "Enable companion Bazarr Anime instance for dedicated anime subtitle management.";
      };

      port = mkOption {
        type = types.port;
        default = 6768;
        description = "Port for Bazarr Anime web interface.";
      };

      subdomain = mkOption {
        type = types.str;
        default = "bazarr-anime";
        description = "Subdomain name for Bazarr Anime reverse proxy routing.";
      };
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
        assertion = !animeEnabled || config.sops.secrets ? arr_sonarr_anime_api_key;
        message = "arr.bazarr.anime: config.sops.secrets.arr_sonarr_anime_api_key must be defined when Bazarr Anime is enabled.";
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

    # Ensure Bazarr writes subtitle files with group-writable permissions (rw-rw-r--)
    systemd.services.bazarr.serviceConfig.UMask = "0002";

    sops.secrets.arr_jellyfin_api_key.restartUnits = mkIf cfg.jellyfin.enable (
      ["bazarr.service"]
      ++ lib.optional animeEnabled "bazarr-anime.service"
    );

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
          enabled_providers = [
            "animetosho"
            "embeddedsubtitles"
            "opensubtitlescom"
            "yifysubtitles"
          ];
          movie_default_enabled = true;
          movie_default_profile = 1;
          serie_default_enabled = true;
          serie_default_profile = 1;
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
          movie_library = ["Movies"];
          movie_library_ids = ["f137a2dd21bbc1b99aa5c0f6bf02a805"];
          series_library = ["Anime" "Shows"];
          series_library_ids = [
            "0c41907140d802bb58430fed7e2cd79e"
            "a656b907eb3a73532e40e44b968d0225"
          ];
          refresh_method = "immediate";
        };
      };
    };

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
        exec ${pkgs.python3}/bin/python3 ${../scripts/bazarr-setup.py} /var/lib/bazarr/db
      '';
    };

    # =========================================================================
    # Bazarr Anime Companion Instance (Port 6768) - Dedicated Anime Subtitles
    # =========================================================================
    systemd.tmpfiles.settings."10-bazarr-anime" = mkIf animeEnabled {
      "/var/lib/bazarr-anime".d = {
        user = bazarrUser;
        group = cfg.mediaGroup;
        mode = "0755";
      };
    };

    systemd.services.bazarr-anime-setup-profile = mkIf animeEnabled {
      description = "Ensure default language profiles in Bazarr Anime database";
      before = ["bazarr-anime.service"];
      wantedBy = ["multi-user.target"];

      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        User = bazarrUser;
        Group = cfg.mediaGroup;
        StateDirectory = "bazarr-anime";
      };

      script = ''
        exec ${pkgs.python3}/bin/python3 ${../scripts/bazarr-setup.py} /var/lib/bazarr-anime/db
      '';
    };

    systemd.services.bazarr-anime = mkIf animeEnabled {
      description = "Bazarr Anime";
      after = ["network.target"];
      wantedBy = ["multi-user.target"];

      environment = animeEnv;

      script = ''
        DYNACONF_auth__apikey="@json $(${lib.getExe pkgs.jq} -n --rawfile k "$CREDENTIALS_DIRECTORY/auth.apikey" '$k | trim')"
        export DYNACONF_auth__apikey
        DYNACONF_sonarr__apikey="@json $(${lib.getExe pkgs.jq} -n --rawfile k "$CREDENTIALS_DIRECTORY/sonarr.apikey" '$k | trim')"
        export DYNACONF_sonarr__apikey
        ${lib.optionalString cfg.jellyfin.enable ''
          DYNACONF_jellyfin__apikey="@json $(${lib.getExe pkgs.jq} -n --rawfile k "$CREDENTIALS_DIRECTORY/jellyfin.apikey" '$k | trim')"
          export DYNACONF_jellyfin__apikey
        ''}
        exec ${lib.getExe pkgs.bazarr} --config /var/lib/bazarr-anime --no-update
      '';

      serviceConfig =
        (builtins.removeAttrs config.systemd.services.bazarr.serviceConfig ["ExecStart"])
        // {
          SyslogIdentifier = "bazarr-anime";
          StateDirectory = "bazarr-anime";
          LoadCredential =
            [
              "auth.apikey:${config.sops.secrets.arr_bazarr_api_key.path}"
              "sonarr.apikey:${config.sops.secrets.arr_sonarr_anime_api_key.path}"
            ]
            ++ lib.optional cfg.jellyfin.enable "jellyfin.apikey:${config.sops.secrets.arr_jellyfin_api_key.path}";
        };
      unitConfig.RequiresMountsFor = ["/var/lib/bazarr-anime"];
    };
  };
}
