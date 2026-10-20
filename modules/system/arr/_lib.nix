{
  # Reference helper to format secret for Nixflix or native modules
  secretRef = secretPath: {_secret = secretPath;};

  # Standard wildcard bind address for Servarr services (required for Nixflix normalization to 127.0.0.1)
  bindAddress = "0.0.0.0";

  # Standard local loopback address for internal inter-service communication
  localAddress = "127.0.0.1";

  # Standard host-header allowlist for local loopback, INADDR_ANY (used by Nixflix internal scripts), host name, and Tailscale domain
  mkAllowedHosts = hostName: tailscaleDomain: "localhost,127.0.0.1,0.0.0.0,${hostName},${hostName}.${tailscaleDomain}";
}
