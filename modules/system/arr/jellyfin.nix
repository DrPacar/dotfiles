{
  config,
  pkgs,
  lib,
  ...
}: let
  inherit (lib) mkOption mkIf types optionals;
  cfg = config.arr;
  inherit (import ./_lib.nix) secretRef;

  jellyfinUser = "jellyfin";
in {
  options.arr.jellyfin = {
    enable = mkOption {
      type = types.bool;
      default = true;
      description = "Enable Jellyfin media server.";
    };

    port = mkOption {
      type = types.port;
      default = 8096;
      description = "Port for Jellyfin web interface.";
    };

    adminUser = mkOption {
      type = types.str;
      default = config.user.primary;
      description = "Initial Jellyfin administrator username created by the setup wizard.";
    };

    hardwareAcceleration = mkOption {
      type = types.enum ["none" "qsv" "vaapi"];
      default = "none";
      description = "Hardware acceleration mode for Jellyfin transcoding.";
    };

    device = mkOption {
      type = types.str;
      default = "/dev/dri/by-path/pci-0000:00:02.0-render";
      description = "Path to the DRM render node for hardware acceleration.";
    };
  };

  config = mkIf (cfg.enable && cfg.jellyfin.enable) {
    hardware.graphics = mkIf (cfg.jellyfin.hardwareAcceleration != "none") {
      enable = true;
      extraPackages =
        [
          pkgs.intel-media-driver
          pkgs.intel-compute-runtime
        ]
        ++ optionals (cfg.jellyfin.hardwareAcceleration == "qsv") [
          pkgs.vpl-gpu-rt
        ];
    };

    users.users.${jellyfinUser}.extraGroups =
      mkIf (cfg.jellyfin.hardwareAcceleration != "none") ["video" "render"];

    sops.secrets.arr_jellyfin_admin_password.restartUnits = ["jellyfin.service"];
    sops.secrets.arr_jellyfin_api_key.restartUnits = ["jellyfin.service"];

    systemd.services.jellyfin = let
      jellyfinSyncScript = pkgs.writeShellScript "jellyfin-sync-credentials" ''
                set -eu

                DB_PATH="/var/lib/jellyfin/data/jellyfin.db"
                PASS_FILE="${config.sops.secrets.arr_jellyfin_admin_password.path}"
                KEY_FILE="${config.sops.secrets.arr_jellyfin_api_key.path}"
                ADMIN_USER="${cfg.jellyfin.adminUser}"

                if [ ! -f "$DB_PATH" ] || [ ! -f "$PASS_FILE" ] || [ ! -f "$KEY_FILE" ]; then
                  exit 0
                fi

                ${pkgs.python3}/bin/python3 - "$DB_PATH" "$ADMIN_USER" "$PASS_FILE" "$KEY_FILE" <<'EOF'
        import sys, os, sqlite3, hashlib

        db_path = sys.argv[1]
        admin_user = sys.argv[2]
        pass_file = sys.argv[3]
        key_file = sys.argv[4]

        with open(pass_file, "r") as f:
            password = f.read().strip()

        with open(key_file, "r") as f:
            api_key = f.read().strip()

        conn = sqlite3.connect(db_path)
        cur = conn.cursor()

        # 1. Synchronize Admin User Password
        cur.execute("SELECT Id, Password, InvalidLoginAttemptCount FROM Users WHERE Username = ?", (admin_user,))
        row = cur.fetchone()
        if row:
            user_id, current_hash, invalid_attempts = row
            match = False
            if current_hash and current_hash.startswith("$PBKDF2-SHA512$iterations="):
                try:
                    parts = current_hash.split("$")
                    iterations = int(parts[2].split("=")[1])
                    salt = bytes.fromhex(parts[3])
                    expected_hash = parts[4].upper()
                    computed = hashlib.pbkdf2_hmac("sha512", password.encode("utf-8"), salt, iterations, dklen=64).hex().upper()
                    if computed == expected_hash:
                        match = True
                except Exception as e:
                    print(f"Error checking password hash: {e}", file=sys.stderr)

            if not match:
                salt = os.urandom(16)
                salt_hex = salt.hex().upper()
                new_hash_hex = hashlib.pbkdf2_hmac("sha512", password.encode("utf-8"), salt, 210000, dklen=64).hex().upper()
                new_formatted_hash = "$PBKDF2-SHA512$iterations=210000$" + salt_hex + "$" + new_hash_hex
                cur.execute("UPDATE Users SET Password = ?, InvalidLoginAttemptCount = 0 WHERE Username = ?", (new_formatted_hash, admin_user))
                print(f"Synchronized Jellyfin password for user {admin_user}")
            elif invalid_attempts > 0:
                cur.execute("UPDATE Users SET InvalidLoginAttemptCount = 0 WHERE Username = ?", (admin_user,))
                print(f"Reset InvalidLoginAttemptCount for user {admin_user}")

        # 2. Synchronize nixflix ApiKey
        if api_key:
            cur.execute("SELECT AccessToken FROM ApiKeys WHERE Name = 'nixflix'")
            key_row = cur.fetchone()
            if not key_row or key_row[0] != api_key:
                cur.execute("DELETE FROM ApiKeys WHERE Name = 'nixflix' OR AccessToken = ?", (api_key,))
                cur.execute("INSERT INTO ApiKeys (AccessToken, Name, DateCreated, DateLastActivity) VALUES (?, 'nixflix', datetime('now'), datetime('now'))", (api_key,))
                print("Synchronized nixflix API key in Jellyfin DB")

        conn.commit()
        conn.close()
        EOF

                chown jellyfin:${cfg.mediaGroup} "$DB_PATH"* 2>/dev/null || true
                chmod 644 "$DB_PATH"* 2>/dev/null || true
      '';
    in {
      serviceConfig.ExecStartPre = [
        "+${jellyfinSyncScript}"
      ];
    };

    nixflix.jellyfin = {
      enable = true;
      user = jellyfinUser;
      group = cfg.mediaGroup;
      network.internalHttpPort = cfg.jellyfin.port;
      openFirewall = false;
      apiKey = secretRef config.sops.secrets.arr_jellyfin_api_key.path;

      users.${cfg.jellyfin.adminUser} = {
        policy.isAdministrator = true;
        password = secretRef config.sops.secrets.arr_jellyfin_admin_password.path;
      };

      libraries = {
        Movies = {
          collectionType = "movies";
          paths = ["${cfg.dataDir}/media/movies"];
        };
        Series = {
          collectionType = "tvshows";
          paths = ["${cfg.dataDir}/media/tv"];
        };
        Anime = {
          collectionType = "tvshows";
          paths = ["${cfg.dataDir}/media/anime"];
        };
      };

      # Optimal encoding configuration varies between devices - be careful.
      # Configuration for: 12th Gen Intel(R) Core(TM) i7-12700K
      encoding = {
        enableHardwareEncoding = cfg.jellyfin.hardwareAcceleration != "none";
        hardwareAccelerationType = cfg.jellyfin.hardwareAcceleration;
        vaapiDevice = cfg.jellyfin.device;
        qsvDevice = cfg.jellyfin.device;

        allowHevcEncoding = true;

        hardwareDecodingCodecs = [
          "h264"
          "hevc"
          "mpeg2video"
          "vc1"
          "vp8"
          "vp9"
          "av1"
        ];
        enableDecodingColorDepth10Hevc = true;
        enableDecodingColorDepth10Vp9 = true;

        enableIntelLowPowerH264HwEncoder = true;
        enableIntelLowPowerHevcHwEncoder = true;

        enableTonemapping = true;
        enableVppTonemapping = true;
      };
    };
  };
}
