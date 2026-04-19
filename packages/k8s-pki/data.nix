{
  self,
  lib,
  system,
}: let
  k8sLib = lib.k8s-pki;
  cfgs = self.nixosConfigurations;

  systemHosts =
    lib.filterAttrs
    (_: v: v.pkgs.stdenv.hostPlatform.system == system)
    cfgs;

  k8sHosts =
    lib.filterAttrs
    (_: v: (v.config.capybara.app.server.kubernetes.enable or false))
    systemHosts;

  hosts =
    lib.mapAttrs (name: v: let
      k = v.config.capybara.app.server.kubernetes;
    in {
      inherit name;
      inherit (k) role advertiseIP masterAddress;
      hostPubkeys = v.config.capybara.agenix.hostPubkeys;
    })
    k8sHosts;

  # Users are discovered across every host (not only k8s hosts), because a
  # workstation enabling kube-cli needs its own client certs even when it is
  # not itself a cluster node.
  users =
    lib.concatMapAttrs (
      hostName: v: let
        hmUsers = v.config.home-manager.users or {};
      in
        lib.mapAttrs' (
          uname: u:
            lib.nameValuePair "${uname}@${hostName}" {
              name = uname;
              host = hostName;
              userPubkeys = u.capybara.agenix.userPubkeys or [];
            }
        )
        (lib.filterAttrs
          (_: u: (u.capybara.app.dev.kube-cli.enable or false))
          hmUsers)
    )
    systemHosts;

  specs = k8sLib.specs;
  recipients = k8sLib.recipients {inherit hosts users;};
in {
  inherit hosts users specs recipients;
}
