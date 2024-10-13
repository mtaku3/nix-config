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
    version = "2.3";

    src = fetchFromGitHub {
      owner = "mtaku3";
      repo = "cadnano2";
      rev = "v2.3";
      hash = "sha256-1+7lZp+bz2ho2+cR6mhqXYLDyS9jyFkNqPOfIOIXJZY=";
    };

    doCheck = false;
    nativeBuildInputs = [qt5.wrapQtAppsHook copyDesktopItems];
    buildInputs = [qt5.qtbase];
    propagatedBuildInputs = with python310Packages; [
      pyqt5
      networkx
    ];

    preFixup = ''
      makeWrapperArgs+=("''${qtWrapperArgs[@]}")
    '';

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
