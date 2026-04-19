{lib, ...}: {
  specs = import ./specs.nix;
  recipients = import ./recipients.nix {inherit lib;};
}
