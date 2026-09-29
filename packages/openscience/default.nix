{
  lib,
  stdenvNoCC,
  fetchurl,
  patchelf,
  glibc,
  ...
}:
stdenvNoCC.mkDerivation rec {
  pname = "openscience";
  version = "2.0.145";

  src = fetchurl {
    url = "https://github.com/synthetic-sciences/openscience/releases/download/v${version}/openscience-linux-x64.tar.gz";
    hash = "sha256-cT+iOFUNl+taMrGeLdMxhRsTjZKOMQ6x5kRySqjePSQ=";
  };

  sourceRoot = ".";

  nativeBuildInputs = [patchelf];

  # A `bun build --compile` binary: the JS bundle is appended to the ELF, so
  # stripping would cut it off. It links nothing beyond glibc, which makes
  # pointing the interpreter at the store's loader all the patching it needs.
  dontStrip = true;
  dontPatchELF = true;

  installPhase = ''
    runHook preInstall

    install -Dm755 openscience "$out/bin/openscience"
    patchelf --set-interpreter ${glibc}/lib/ld-linux-x86-64.so.2 "$out/bin/openscience"

    runHook postInstall
  '';

  doInstallCheck = true;
  # Even --version creates its data root under $HOME first.
  installCheckPhase = ''
    export HOME="$(mktemp -d)"
    [ "$("$out/bin/openscience" --version)" = "${version}" ]
  '';

  meta = {
    description = "Open-source AI workbench for scientific research";
    homepage = "https://github.com/synthetic-sciences/openscience";
    license = lib.licenses.asl20;
    mainProgram = "openscience";
    platforms = ["x86_64-linux"];
    sourceProvenance = [lib.sourceTypes.binaryNativeCode];
  };
}
