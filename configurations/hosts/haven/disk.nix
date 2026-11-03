{inputs, ...}: {
  imports = [
    inputs.disko.nixosModules.disko
  ];

  zramSwap.enable = true;

  disko.devices.disk = {
    main = {
      device = "/dev/disk/by-id/nvme-Samsung_SSD_980_500GB_S64DNX0T106227L";
      type = "disk";
      content = {
        type = "gpt";
        partitions = {
          boot = {
            size = "1G";
            type = "EF00";
            content = {
              type = "filesystem";
              format = "vfat";
              mountpoint = "/boot";
              mountOptions = ["fmask=0077" "dmask=0077"];
            };
          };
          root = {
            size = "100%";
            content = {
              type = "filesystem";
              format = "ext4";
              mountpoint = "/";
              mountOptions = ["defaults" "noatime"];
            };
          };
        };
      };
    };
  };
}
