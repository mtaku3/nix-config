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
  upstreamVersion = "2.0.145";
  rev = "e6cabf38";
  version = "${upstreamVersion}-${rev}";

  src = fetchurl {
    url = "https://github.com/mtaku3/openscience/releases/download/v${upstreamVersion}-${rev}/openscience-linux-x64.tar.gz";
    hash = "sha256-zns23ZU3MmO8zBxs2osGxx61uGI6Y/P4dJzFToL5Za8=";
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
    homepage = "https://github.com/mtaku3/openscience";
    license = lib.licenses.asl20;
    mainProgram = "openscience";
    platforms = ["x86_64-linux"];
    sourceProvenance = [lib.sourceTypes.binaryNativeCode];
  };
}
