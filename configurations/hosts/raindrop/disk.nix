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
      device = "/dev/disk/by-id/nvme-KXG8AZNV1T02_LA_KIOXIA_937FB1COFS9U";
      type = "disk";
      content = {
        type = "gpt";
        partitions = {
          # Partition 1: EFI System Partition
          boot = {
            priority = 1;
            type = "EF00";
            start = "2048s";
            end = "8390655s";
            uuid = "931c9830-3b19-435c-8306-5df62b4dbc9e";
            label = "EFI System Partition";
            content = {
              type = "filesystem";
              format = "vfat";
              mountpoint = "/boot";
              mountOptions = ["fmask=0077" "dmask=0077"];
            };
          };

          # Partition 2: Microsoft Reserved Partition (Windows MSR - unmanaged)
          msr = {
            priority = 2;
            type = "0C01";
            start = "8390656s";
            end = "8423423s";
            uuid = "481321b0-b4c9-4cc6-acff-695d31b2683b";
            label = "Microsoft reserved partition";
          };

          # Partition 3: Windows C: Drive (NTFS - unmanaged)
          windows = {
            priority = 3;
            type = "0700";
            start = "8423424s";
            end = "1689133055s";
            uuid = "47a917fa-fe69-4fed-9aad-9de91887402a";
            label = "Basic data partition";
          };

          # Partition 4: Windows Recovery (NTFS - unmanaged)
          recovery = {
            priority = 4;
            type = "2700";
            start = "1689133056s";
            end = "1691250687s";
            uuid = "33128c6d-73b1-44d7-bf0b-5112535acc8e";
          };

          # Partition 5: NixOS Root Filesystem
          root = {
            priority = 5;
            type = "8300";
            start = "1691250688s";
            end = "1998450687s";
            uuid = "d664104c-e78f-4a00-92f8-ced336151d54";
            label = "root";
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
