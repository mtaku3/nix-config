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

  networking.hostId = "cd24c51a";

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
    # DMZ (VLAN 30). The PVE NIC carries tag=30, so the guest sees it untagged.
    interfaces.ens18 = {
      ipv4.addresses = [
        {
          address = "192.168.30.10";
          prefixLength = 24;
        }
      ];
    };
    # The public IP lives on lo so the RTX can route LAN traffic for it here
    # (RTX1210 has no hairpin NAT); Docker's DNAT matches any local address.
    interfaces.lo.ipv4.addresses = [
      {
        address = "202.215.58.76";
        prefixLength = 32;
      }
    ];
    defaultGateway = {
      address = "192.168.30.1";
      interface = "ens18";
    };
    nameservers = ["1.1.1.1" "1.0.0.1"];
    enableIPv6 = false;
  };

  # Since 26.05 the scripted address units are only wanted by their device,
  # and lo has none, so network-addresses-lo never starts and the public IP
  # above stays unassigned. Pull it in with the network like 25.11 did.
  systemd.services.network-addresses-lo.wantedBy = ["network.target"];

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
}
