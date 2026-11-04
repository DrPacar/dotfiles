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
  animeEnabled = cfg.enable && cfg.bazarr.enable && cfg.bazarr.anime.enable && cfg.sonarr.anime.enable;

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
    use_subsync = cfg.bazarr.subsync.enable;
    auto_use_original_language = cfg.bazarr.subsync.autoUseOriginalLanguage;
    use_original_language = cfg.bazarr.subsync.useOriginalLanguage;
    gss = cfg.bazarr.subsync.gss;
    no_fix_framerate = cfg.bazarr.subsync.noFixFramerate;
  };

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
        chmod = "0664";
        chmod_enabled = true;
        subfolder = "current";
        utf8_encode = true;
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
  config = mkIf animeEnabled {
    systemd.tmpfiles.settings."10-bazarr-anime" = {
      "/var/lib/bazarr-anime".d = {
        user = bazarrUser;
        group = cfg.mediaGroup;
        mode = "0755";
      };
    };

    systemd.services.bazarr-anime-setup-profile = {
      description = "Ensure default language profiles in Bazarr Anime database";
      before = ["bazarr-anime.service"];
      wantedBy = ["multi-user.target"];

      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        User = bazarrUser;
        Group = cfg.mediaGroup;
        StateDirectory = "bazarr-anime";
        Slice = "arr.slice";
      };

      script = ''
        exec ${pkgs.python3}/bin/python3 ${../../scripts/bazarr-setup.py} /var/lib/bazarr-anime/db
      '';
    };

    systemd.services.bazarr-anime = {
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
          Slice = "arr.slice";
          MemoryHigh = "1G";
          MemoryMax = "1.5G";
          Restart = "on-failure";
          RestartSec = 15;
          UMask = "0002";
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
