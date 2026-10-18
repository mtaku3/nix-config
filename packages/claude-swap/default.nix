{
  lib,
  pkgs,
  ...
}:
# Built against unstable: claude-swap needs textual>=8.2.8, while nixos-25.11
# ships textual 6.x.
with pkgs.unstable.python3Packages;
  buildPythonApplication rec {
    pname = "claude-swap";
    version = "0.27.2";

    src = fetchPypi {
      pname = "claude_swap";
      inherit version;
      hash = "sha256-jKhR/YkfuACZV5yC85sSt6uPwGZKXtSdCp6gHXcQDIE=";
    };

    pyproject = true;

    build-system = [hatchling];

    dependencies = [
      textual
      truststore
    ];

    doCheck = false;
    pythonImportsCheck = ["claude_swap"];

    meta = {
      description = "Switch between multiple Claude Code accounts";
      homepage = "https://github.com/realiti4/claude-swap";
      license = lib.licenses.mit;
      mainProgram = "cswap";
      platforms = lib.platforms.linux ++ lib.platforms.darwin;
    };
  }
