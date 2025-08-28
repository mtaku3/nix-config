{
  lib,
  pkgs,
  ...
}:
with lib;
with lib.capybara;
with pkgs.python311Packages;
  buildPythonApplication {
    pname = "superclaude";
    version = "4.0.8";

    src = fetchPypi {
      inherit pname version;
      sha256 = "sha256-pd5+Zlaan9pxU9L15hPEiLEA22Hi2QhxaQFl2IijEE8=";
    };

    pyproject = true;

    nativeBuildInputs = [
      setuptools
      wheel
    ];

    postPatch = ''
      substituteInPlace pyproject.toml \
        --replace 'SuperClaude = "SuperClaude.__main__:main"' ""
    '';

    doCheck = false;
    pythonImportsCheck = ["SuperClaude"];
  }
