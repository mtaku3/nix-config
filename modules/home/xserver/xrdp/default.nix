{
  lib,
  config,
  pkgs,
  ...
}:
with lib;
with lib.capybara; let
  top = config.capybara.xserver;
  cfg = top.xrdp;
in {
  options.capybara.xserver.xrdp = {
    enable = mkBoolOpt false "Whether to enable the xrdp";
    session = mkOpt (types.enum ["xmonad"]) "xmonad" "Window manager to be used for xrdp";
  };

  config = mkIf cfg.enable {
    home.file.".xrdp.sh".source = pkgs.writeShellScript "startwm" ''
      exec ${pkgs.runtimeShell} ~/.xinitrc ${cfg.session}
    '';
  };
}
