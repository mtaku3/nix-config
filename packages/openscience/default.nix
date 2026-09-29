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

  dontStrip = true;
  dontPatchELF = true;

  installPhase = ''
    runHook preInstall

    install -Dm755 openscience "$out/bin/openscience"
    patchelf --set-interpreter ${glibc}/lib/ld-linux-x86-64.so.2 "$out/bin/openscience"

    runHook postInstall
  '';

  doInstallCheck = true;
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
