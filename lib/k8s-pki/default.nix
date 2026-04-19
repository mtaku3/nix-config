{lib, ...}: {
  k8s-pki = {
    specs = import ./specs.nix;
    recipients = import ./recipients.nix {inherit lib;};
  };
}
