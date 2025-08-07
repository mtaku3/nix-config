{
  lib,
  pkgs,
  ...
}:
with lib;
with lib.capybara;
  pkgs.stdenvNoCC.mkDerivation rec {
    pname = "ccusage";
    version = "15.7.1";

    src = pkgs.fetchFromGitHub {
      owner = "ryoppippi";
      repo = "ccusage";
      tag = "v${version}";
      hash = "sha256-X+lMsM/ypJXlD/GEML/Ff145+MbP6QZ4RnRHYJMnU0I=";
    };

    nativeBuildInputs = [pkgs.bun];

    configurePhase = ''
      runHook preConfigure

      export BUN_INSTALL_CACHE_DIR=$(mktemp -d)

      bun install \
        --frozen-lockfile \
        --no-progress

      runHook postConfigure
    '';

    buildPhase = ''
      runHook preBuild

      bun build \
        --compile \
        --minify \
        --outfile=ccusage \
        ./src/index.ts

      runHook postBuild
    '';

    installPhase = ''
      runHook preInstall

      mkdir -p $out/bin
      install -Dm755 ccusage $out/bin/ccusage

      runHook postInstall
    '';
  }
