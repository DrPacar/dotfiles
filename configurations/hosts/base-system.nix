{
  config,
  pkgs,
  ...
}: {
  nix.settings = {
    experimental-features = ["nix-command" "flakes"];
    extra-substituters = ["https://noctalia.cachix.org"];
    extra-trusted-public-keys = ["noctalia.cachix.org-1:pCOR47nnMEo5thcxNDtzWpOxNFQsBRglJzxWPp3dkU4="];
    auto-optimise-store = true;
    warn-dirty = false;
  };

  nixpkgs.config.allowUnfree = true;

  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 14d";
  };

  time.timeZone = "Europe/Vienna";

  i18n.defaultLocale = "en_US.UTF-8";
  i18n.extraLocaleSettings = {
    LC_ADDRESS = "de_AT.UTF-8";
    LC_IDENTIFICATION = "de_AT.UTF-8";
    LC_MEASUREMENT = "de_AT.UTF-8";
    LC_MONETARY = "de_AT.UTF-8";
    LC_NAME = "de_AT.UTF-8";
    LC_NUMERIC = "de_AT.UTF-8";
    LC_TIME = "de_AT.UTF-8";
  };

  console = {
    font = "Lat2-Terminus16";
    keyMap = "de";
  };

  services.flatpak.enable = true;

  # Enable Nix dynamic linker (needed by Jetbrains)
  programs.nix-ld.enable = true;

  services.printing = {
    enable = true;
    drivers = with pkgs; [
      brlaser
      gutenprint
    ];
  };

  # Enable Avahi for network discovery
  services.avahi = {
    enable = true;
    nssmdns4 = true;
    openFirewall = true;
  };

  xdg.portal = {
    enable = true;
    config.common.default = "*";
    extraPortals = [pkgs.xdg-desktop-portal-gtk];
  };

  # Audio
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    pulse.enable = true;
  };

  hardware.graphics.enable = true;
}
