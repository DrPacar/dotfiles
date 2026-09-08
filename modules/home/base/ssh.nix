{
  pkgs,
  meta,
  ...
}: {
  programs.ssh = {
    enable = true;
    enableDefaultConfig = false;
    settings."*" = {
      AddKeysToAgent = "yes";
      Compression = true;
      ServerAliveInterval = 60;
      ServerAliveCountMax = 3;
      HashKnownHosts = true;
      ControlMaster = "auto";
      ControlPath = "~/.ssh/cm-%r@%h:%p";
      ControlPersist = "10m";
    };
  };
}
