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
    services.pipewire.wireplumber.extraConfig = {
      "monitor.bluez.properties" = {
        "bluez5.enable-sbc-xq" = true;
        "bluez5.enable-msbc" = true;
        "bluez5.enable-hw-volume" = true;
        "bluez5.roles" = ["hsp_hs" "hsp_ag" "hfp_hf" "hfp_ag"];
      };
    };

    capybara.impermanence.directories = [
      "/var/lib/bluetooth"
    ];
  };
}
