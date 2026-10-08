{pkgs, ...}: let
  kdeconnectSyncShared = pkgs.writeShellApplication {
    name = "kdeconnect-sync-shared";
    runtimeInputs = with pkgs; [python3 systemd];
    text = ''
      python3 - << 'EOF'
      import configparser
      import os
      import subprocess

      config_file = os.path.expanduser("~/.config/kdeconnect/trusted_devices")
      shared_base = os.path.expanduser("~/shared")

      if os.path.exists(config_file):
          os.makedirs(shared_base, exist_ok=True)
          parser = configparser.ConfigParser()
          parser.read(config_file)
          for dev_id in parser.sections():
              dev_name = parser.get(dev_id, "name", fallback=dev_id)
              # Sanitize device name to ensure a safe directory name
              safe_name = "".join(c for c in dev_name if c.isalnum() or c in ("-", "_", " ")).strip()
              if not safe_name:
                  safe_name = dev_id

              target_dir = os.path.join(shared_base, safe_name)
              os.makedirs(target_dir, exist_ok=True)

              share_config_dir = os.path.expanduser(f"~/.config/kdeconnect/{dev_id}/kdeconnect_share")
              os.makedirs(share_config_dir, exist_ok=True)
              share_config_file = os.path.join(share_config_dir, "config")

              current_path = None
              if os.path.exists(share_config_file):
                  sp = configparser.ConfigParser()
                  sp.read(share_config_file)
                  current_path = sp.get("General", "incoming_path", fallback=None)

              if current_path != target_dir:
                  sp = configparser.ConfigParser()
                  sp["General"] = {"incoming_path": target_dir}
                  with open(share_config_file, "w") as f:
                      sp.write(f)

                  try:
                      subprocess.run([
                          "busctl", "--user", "call", "org.kde.kdeconnect",
                          f"/modules/kdeconnect/devices/{dev_id}",
                          "org.kde.kdeconnect.device", "reloadPlugins"
                      ], check=False, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
                  except Exception:
                      pass
      EOF
    '';
  };
in {
  services.kdeconnect = {
    enable = true;
    indicator = true;
  };

  # Automatically create and sync per-device ~/shared/<deviceName> folders
  systemd.user.services.kdeconnect-sync-shared = {
    Unit = {
      Description = "Sync KDE Connect device shared folders to ~/shared/<deviceName>";
      After = ["kdeconnect.service"];
    };
    Service = {
      Type = "oneshot";
      ExecStart = "${kdeconnectSyncShared}/bin/kdeconnect-sync-shared";
    };
    Install = {
      WantedBy = ["graphical-session.target" "default.target"];
    };
  };

  # Trigger folder sync whenever trusted_devices is modified
  systemd.user.paths.kdeconnect-sync-shared = {
    Unit = {
      Description = "Watch KDE Connect trusted_devices for changes";
    };
    Path = {
      PathModified = "%h/.config/kdeconnect/trusted_devices";
      Unit = "kdeconnect-sync-shared.service";
    };
    Install = {
      WantedBy = ["graphical-session.target" "default.target"];
    };
  };
}
