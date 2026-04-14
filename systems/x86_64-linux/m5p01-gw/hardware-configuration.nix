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

  boot.initrd.availableKernelModules = ["ata_piix" "uhci_hcd" "virtio_pci" "sr_mod" "virtio_blk"];
  boot.initrd.kernelModules = [];
  boot.kernelModules = ["kvm-intel"];
  boot.extraModulePackages = [];

  boot.loader.grub.enable = true;

  networking = {
    useDHCP = false;
    networkmanager.enable = lib.mkForce false;
    interfaces.ens3 = {
      ipv4.addresses = [
        {
          address = "133.18.105.254";
          prefixLength = 23;
        }
      ];
      ipv6.addresses = [
        {
          address = "2406:8c00:0:3447:133:18:105:254";
          prefixLength = 64;
        }
      ];
    };
    defaultGateway = {
      address = "133.18.104.1";
      interface = "ens3";
    };
    defaultGateway6 = {
      address = "2406:8c00:0:3447::1";
      interface = "ens3";
    };
    nameservers = ["210.134.55.219" "210.134.48.31"];
  };

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
}
