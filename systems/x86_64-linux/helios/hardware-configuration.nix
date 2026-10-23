{
  config,
  lib,
  modulesPath,
  inputs,
  ...
}: {
  imports = [
    (modulesPath + "/profiles/qemu-guest.nix")
    inputs.disko.nixosModules.disko
    ./disko-config.nix
  ];

  networking.hostId = "09ac8919";

  boot.initrd.availableKernelModules = ["uhci_hcd" "ehci_pci" "ahci" "virtio_pci" "virtio_scsi" "sd_mod" "sr_mod"];
  boot.initrd.kernelModules = [];
  boot.kernelModules = ["kvm-amd"];
  boot.extraModulePackages = [];

  boot.loader = {
    efi.canTouchEfiVariables = true;
    grub = {
      enable = true;
      device = "nodev";
      efiSupport = true;
    };
  };
  boot.zfs.devNodes = "/dev/disk/by-path";

  # Erase the root dataset on every boot. Runs after the pool is imported and
  # before it is mounted as /sysroot.
  boot.initrd.systemd.services.rollback = {
    description = "Roll back the root dataset to its blank snapshot";
    wantedBy = ["initrd.target"];
    after = ["zfs-import-rpool.service"];
    before = ["sysroot.mount"];
    path = [config.boot.zfs.package];
    unitConfig.DefaultDependencies = "no";
    serviceConfig.Type = "oneshot";
    script = "zfs rollback -r rpool/local/root@blank";
  };

  fileSystems."/persist".neededForBoot = true;
  fileSystems."/home".neededForBoot = true;

  networking = {
    useDHCP = false;
    interfaces.ens18 = {
      ipv4.addresses = [
        {
          address = "192.168.11.101";
          prefixLength = 24;
        }
      ];
    };
    defaultGateway = {
      address = "192.168.11.1";
      interface = "ens18";
    };
    nameservers = ["1.1.1.1" "1.0.0.1"];
    enableIPv6 = false;
  };

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
}
