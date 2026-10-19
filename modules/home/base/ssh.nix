{osConfig, ...}: {
  services.ssh-agent.enable = true;

  programs.ssh = {
    enable = true;
    enableDefaultConfig = false;

    settings = {
      "github.com" = {
        User = "git";
      };

      "*" = {
        IdentityFile = [
          "~/.ssh/${osConfig.networking.hostName}"
          "~/.ssh/id_ed25519"
        ];

        IdentitiesOnly = true;

        AddKeysToAgent = "yes";

        ControlMaster = "auto";
        ControlPath = "/run/user/%i/ssh-%C";
        ControlPersist = "10m";

        ServerAliveInterval = 30;
        ServerAliveCountMax = 3;

        ForwardAgent = false;
        HashKnownHosts = true;
        StrictHostKeyChecking = "accept-new";
      };
    };
  };
}
