{ self, inputs, ... }:
{
  flake.nixosModules.raindropConfiguration =
    {
      pkgs,
      lib,
      config,
      ...
    }:
    {
      imports = [ self.nixosModules.raindropHardware ];

      nix.settings.experimental-features = [
        "nix-command"
        "flakes"
      ];

      # Bootloader
      boot.loader.grub = {
        enable = true;
        efiSupport = true;
        device = "nodev";
        useOSProber = true;
      };
      boot.loader.efi.canTouchEfiVariables = true;

      # Basics
      networking.hostName = "raindrop";
      networking.networkmanager.enable = true;
      time.timeZone = "Europe/Vienna";
      i18n.defaultLocale = "de_AT.UTF-8";

      # Grafik & GNOME (Bewährtes Setup)[cite: 1]
      services.xserver.enable = true;
      services.xserver.displayManager.gdm.enable = true;
      services.xserver.desktopManager.gnome.enable = true;

      services.xserver.xkb = {
        layout = "at";
        variant = "";
      };

      # Audio
      services.pipewire = {
        enable = true;
        alsa.enable = true;
        pulse.enable = true;
      };

      environment.systemPackages = with pkgs; [
          # --- Flake & Rettung ---
          git
          vim
          curl
          wget
          home-manager # wichtig für standalone-verknüpfungen

          # --- Hardware & Diagnose ---
          pciutils
          usbutils
          lm_sensors
          htop

          # --- Netzwerk & VPN (Systemnah) ---
          wireguard-tools
          vpnc
          ethtool

          # --- Container & Dienste ---
          podman-compose
          cockpit
      ];

      programs.fish.enable = true;      
      users.users.luka = {
        isNormalUser = true;
        extraGroups = [ "networkmanager" "wheel" ];
	shell = pkgs.fish;
      };

      nixpkgs.config.allowUnfree = true;
      system.stateVersion = "25.05";
  };
}
