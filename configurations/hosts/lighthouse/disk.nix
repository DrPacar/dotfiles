{inputs, ...}: {
  imports = [
    inputs.disko.nixosModules.disko
  ];

  zramSwap.enable = true;
  swapDevices = [
    {
      device = "/swapfile";
      size = 8192;
    }
  ];

  disko.devices.disk = {
    main = {
      device = "/dev/disk/by-id/nvme-CT2000T500SSD5_24024620A049";
      type = "disk";
      content = {
        type = "gpt";
        partitions = {
          boot = {
            size = "1G";
            type = "EF00";
            uuid = "70a2d1f7-856a-47a7-837b-f6cca9bd08c4";
            content = {
              type = "filesystem";
              format = "vfat";
              mountpoint = "/boot";
              mountOptions = ["fmask=0077" "dmask=0077"];
            };
          };
          root = {
            size = "100%";
            uuid = "b0e4a939-9c5a-4961-9caf-e95d5229f82b";
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

    data = {
      device = "/dev/disk/by-id/nvme-Samsung_SSD_980_500GB_S64DNX0T106230D";
      type = "disk";
      content = {
        type = "gpt";
        partitions = {
          backup = {
            size = "250G";
            content = {
              type = "filesystem";
              format = "ext4";
              mountpoint = "/backup";
              mountOptions = ["defaults" "noatime"];
            };
          };
          vms = {
            size = "100%";
            content = {
              type = "filesystem";
              format = "ext4";
              mountpoint = "/var/lib/libvirt/images";
              mountOptions = ["defaults" "noatime"];
            };
          };
        };
      };
    };
  };
}
