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
        # Host-spezifische Schlüssel
        IdentityFile = [
          "~/.ssh/${osConfig.networking.hostName}"
          "~/.ssh/id_ed25519"
        ];

        # Session & Agent
        AddKeysToAgent = "yes";

        # RAM-basiertes Multiplexing (tmpfs unter /run/user/$UID/)
        ControlMaster = "auto";
        ControlPath = "/run/user/%i/ssh-cm-%r@%h:%p";
        ControlPersist = "10m";

        # Performance & Stabilität
        Compression = true;
        ServerAliveInterval = 30;
        ServerAliveCountMax = 3;
        TCPKeepAlive = true;

        # Sicherheits-Leitplanken
        ForwardAgent = false;
        HashKnownHosts = true;
        StrictHostKeyChecking = "accept-new";
        VisualHostKey = true;

        # Kryptografische Härtung
        KexAlgorithms = [
          "sntrup761x25519-sha512@openssh.com"
          "curve25519-sha256"
          "curve25519-sha256@libssh.org"
          "diffie-hellman-group16-sha512"
          "diffie-hellman-group18-sha512"
        ];
        Ciphers = [
          "chacha20-poly1305@openssh.com"
          "aes256-gcm@openssh.com"
          "aes128-gcm@openssh.com"
        ];
        MACs = [
          "hmac-sha2-512-etm@openssh.com"
          "hmac-sha2-256-etm@openssh.com"
        ];
        HostKeyAlgorithms = [
          "ssh-ed25519"
          "rsa-sha2-512"
          "rsa-sha2-256"
        ];
      };
    };
  };
}
