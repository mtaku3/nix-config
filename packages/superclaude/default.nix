{
  lib,
  pkgs,
  ...
}:
with lib;
with lib.capybara;
with pkgs.python3Packages;
  buildPythonPackage rec {
    pname = "superclaude";
    version = "4.0.8";

    src = fetchPypi {
      inherit pname version;
      hash = "";
    };

    doCheck = false;

    pyproject = true;
    build-system = [
      setuptools
      wheel
    ];
  }
