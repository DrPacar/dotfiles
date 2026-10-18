{pkgs, ...}: {
  environment.systemPackages = with pkgs; [
    openconnect
  ];

  # Scoped sudo rule: allow members of wheel to run openconnect without password
  security.sudo.extraRules = [
    {
      groups = ["wheel"];
      commands = [
        {
          command = "${pkgs.openconnect}/bin/openconnect";
          options = ["NOPASSWD"];
        }
      ];
    }
  ];
}
