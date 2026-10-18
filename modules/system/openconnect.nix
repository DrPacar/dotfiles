{pkgs, ...}: {
  environment.systemPackages = with pkgs; [
    openconnect
    psmisc
  ];

  # Scoped sudo rule: allow members of wheel to run and stop openconnect without password
  security.sudo.extraRules = [
    {
      groups = ["wheel"];
      commands = [
        {
          command = "${pkgs.openconnect}/bin/openconnect";
          options = ["NOPASSWD"];
        }
        {
          command = "/run/current-system/sw/bin/openconnect";
          options = ["NOPASSWD"];
        }
        {
          command = "${pkgs.psmisc}/bin/killall openconnect";
          options = ["NOPASSWD"];
        }
        {
          command = "/run/current-system/sw/bin/killall openconnect";
          options = ["NOPASSWD"];
        }
      ];
    }
  ];
}
