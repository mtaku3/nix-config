{
  lib,
  config,
  pkgs,
  ...
}:
with lib;
with lib.capybara; let
  cfg = config.capybara.xserver.autorandr;
in {
  options.capybara.xserver.autorandr = {
    enable = mkBoolOpt false "Whether to enable the autorandr";
  };

  config = mkIf cfg.enable {
    services.autorandr = {
      enable = true;
      ignoreLid = true;
      profiles = {
        default = {
          fingerprint = {
            "eDP-1" = "00ffffffffffff0006af3d2300000000001b0104951f117802ae95a4554ea0270c505400000001010101010101010101010101010101143780b87038244010103e0035ae100000180000000f0000000000000000000000000020000000fe0041554f0a202020202020202020000000fe004231343048414b30322e33200a00b7";
          };
          config = {
            "eDP-1" = {
              mode = "1920x1080";
              position = "0x0";
              primary = true;
            };
          };
        };
        home = {
          fingerprint = {
            "eDP-1" = "00ffffffffffff0006af3d2300000000001b0104951f117802ae95a4554ea0270c505400000001010101010101010101010101010101143780b87038244010103e0035ae100000180000000f0000000000000000000000000020000000fe0041554f0a202020202020202020000000fe004231343048414b30322e33200a00b7";
            "DP-2" = "00ffffffffffff00430f0027010000000d220103803c21782a4af5ac5147a525105054a56b80714081c0810081809500a9c0b3000101565e00a0a0a029503020350055502100001a023a801871382d40582c450055502100001e000000fd0030901efa3c000a202020202020000000fc00505832373820576176650a202001fb020338f34701020304901f3f230907078301000067030c001000187867d85dc401788000681a000001013090ede305e301e606070160500070c200a0a0a055503020350055502100001af8e300a0a0a032503020350055502100001e000000000000000000000000000000000000000000000000000000000000000000000001";
          };
          config = {
            "eDP-1" = {
              enable = false;
              # mode = "1920x1080";
              # position = "2560x1110";
            };
            "DP-2" = {
              mode = "2560x1440";
              position = "0x0";
              primary = true;
            };
          };
        };
      };
    };
  };
}
