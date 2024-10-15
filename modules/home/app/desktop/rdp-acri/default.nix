{
  lib,
  config,
  pkgs,
  ...
}:
with lib;
with lib.capybara; let
  cfg = config.capybara.app.desktop.rdp-acri;
in {
  options.capybara.app.desktop.rdp-acri = {
    enable = mkBoolOpt false "Whether to enable the rdp-acri";
  };

  config = mkIf cfg.enable {
    capybara.app.desktop.remmina.enable = mkForce true;
    home.packages = [
      (pkgs.writeShellScriptBin
        "rdp-acri"
        ''
          set -e
          tempfile=$(mktemp)
          rm -f $tempfile
          ssh -f -N -M -S $tempfile -L 13389:$1:3389 u_mtaku3@gw.acri.c.titech.ac.jp
          remmina -c rdp://u_mtaku3@localhost:13389
          ssh -S $tempfile -O exit u_mtaku3@gw.acri.c.titech.ac.jp
        '')
    ];
  };
}
