{
  lib,
  config,
  ...
}:
with lib;
with lib.capybara; let
  cfg = config.capybara.system.bluetooth;
in {
  options.capybara.system.bluetooth = with types; {
    enable = mkBoolOpt false "Whether to enable the bluetooth";
  };

  config = mkIf cfg.enable {
    assertions = [
      {
        assertion = config.capybara.system.audio.enable;
        message = "bluetooth module depends on audio module";
      }
    ];

    hardware.bluetooth = enabled;
    environment.etc = {
      "wireplumber/bluetooth.lua.d/51-bluez-config.lua".text = ''
        bluez_monitor.properties = {
          ["bluez5.enable-sbc-xq"] = true,
          ["bluez5.enable-msbc"] = true,
          ["bluez5.enable-hw-volume"] = true,
          ["bluez5.headset-roles"] = "[ hsp_hs hsp_ag hfp_hf hfp_ag ]"
        }
      '';
    };
  };
}
