{
  secretRef = secretPath: {_secret = secretPath;};

  bindAddress = "0.0.0.0";

  localAddress = "127.0.0.1";

  mkAllowedHosts = hostName: tailscaleDomain: "localhost,127.0.0.1,0.0.0.0,${hostName},*.${hostName},${hostName}.${tailscaleDomain},*.${hostName}.${tailscaleDomain},*.ts.net";
}
