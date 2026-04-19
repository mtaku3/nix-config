{
  self,
  lib,
  system,
}: let
  cfgs = self.nixosConfigurations;

  matchingHosts =
    lib.filterAttrs
    (_: v: v.pkgs.stdenv.hostPlatform.system == system)
    cfgs;

  hosts =
    lib.mapAttrs (_: v: {
      hostPubkeys = v.config.capybara.agenix.hostPubkeys or [];
    })
    matchingHosts;

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
        hmUsers
    )
    matchingHosts;
in {
  inherit hosts users;
}
