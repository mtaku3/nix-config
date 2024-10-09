{
  lib,
  pkgs,
  ...
}:
with lib;
with lib.capybara;
with pkgs;
  python310Packages.buildPythonApplication rec {
    pname = "cadnano2";
    version = "2.4.11";

    src = fetchFromGitHub {
      owner = "douglaslab";
      repo = "cadnano2";
      rev = "v${version}";
      hash = "sha256-17S0l7pxPP2xIAZwmuKW76lGTdFxwd4wahyizpAoeu0=";
    };

    preBuild = ''
      rm -rf dist
    '';

    doCheck = false;
    dependencies = with python310Packages; [pyqt6 setuptools];
    nativeBuildInputs = [qt6.wrapQtAppsHook copyDesktopItems];
    buildInputs = [qt6.qtbase];

    desktopItems = [
      (makeDesktopItem {
        name = "cadnano2";
        exec = "cadnano2";
        desktopName = "cadnano";
        categories = ["Science"];
      })
    ];

    meta = {
      description = "Computer-aided design software for DNA origami nanostructures";
      license = "MIT";
      mainProgram = "cadnano2";
    };
  }
