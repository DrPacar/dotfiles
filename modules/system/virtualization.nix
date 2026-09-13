{pkgs, ...}: {
  virtualisation.libvirtd = {
    enable = true;
    qemu = {
      package = pkgs.qemu_kvm;
      runAsRoot = true;
      swtpm.enable = true;
    };
  };

  programs.dconf.enable = true;
  virtualisation.spiceUSBRedirection.enable = true;

  environment.systemPackages = with pkgs; [
    dnsmasq
    (symlinkJoin {
      name = "virt-manager";
      paths = [virt-manager];
      buildInputs = [makeWrapper];
      postBuild = ''
        wrapProgram $out/bin/virt-manager \
          --set GDK_BACKEND x11
      '';
    })
  ];
}
