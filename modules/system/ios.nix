{pkgs, ...}: {
  # USB multiplexing daemon for iOS / iPhone devices
  services.usbmuxd = {
    enable = true;
  };

  # Tools for pairing, mounting and managing iOS devices
  environment.systemPackages = with pkgs; [
    libimobiledevice
    ifuse
    libheif
  ];
}
