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
    name = "capybara-wallpapers";
    src = fs.toSource {
      root = ./pictures;
      fileset = fs.fileFilter (file: file.hasExt "jpg") ./pictures;
    };
    installPhase = "cp -vr . $out";
    meta = {
      name = "Some good wallpapers";
      license = licenses.asl20;
      maintainers = with maintainers; [mtaku3];
    };
  }
