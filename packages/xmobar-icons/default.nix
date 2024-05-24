{
  lib,
  pkgs,
  ...
}:
with lib;
with lib.capybara; let
  fs = fileset;
in
  pkgs.stdenvNoCC.mkDerivation {
    name = "capybara-xmobar-icons";
    src = fs.toSource {
      root = ./xpms;
      fileset = fs.fileFilter (file: file.hasExt "xpm") ./xpms;
    };
    installPhase = "cp -vr . $out";
    meta = {
      name = "Icons to use with xmobar";
      license = licenses.asl20;
      maintainers = with maintainers; [mtaku3];
    };
  }
