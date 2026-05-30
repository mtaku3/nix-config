{
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

  boot.initrd.postResumeCommands = lib.mkAfter ''
    zfs rollback -r rpool/local/root@blank
  '';

  fileSystems."/persist".neededForBoot = true;

  networking = {
    useDHCP = false;
    interfaces.ens18 = {
      ipv4.addresses = [
        {
          address = "192.168.10.101";
          prefixLength = 24;
        }
      ];
    };
    defaultGateway = {
      address = "192.168.10.1";
      interface = "ens18";
    };
    nameservers = ["1.1.1.1" "1.0.0.1"];
    enableIPv6 = false;
  };

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
}
