{ pkgs, meta, ... }: {
  programs.ssh = {
    enable = true;

    addKeysToAgent = "yes";
    compression = true;

    serverAliveInterval = 60;
    serverAliveCountMax = 3;

    hashKnownHosts = true;

    controlMaster = "auto";
    controlPath = "~/.ssh/cm-%r@%h:%p";
    controlPersist = "10m";
  };
}
