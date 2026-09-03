{
  lib,
  stdenv,
  buildNpmPackage,
  fetchFromGitHub,
  nodejs_22,
  python3,
  makeWrapper,
  autoPatchelfHook,
  libuv,
  ...
}:
buildNpmPackage rec {
  pname = "paseo";
  version = "0.7.2";

  src = fetchFromGitHub {
    owner = "getpaseo";
    repo = "paseo";
    rev = "v${version}";
    hash = "sha256-JUVjE32qS29ZNh1tSOLy9YtyPD3+qjhz+W30lWtVqaw=";
  };

  nodejs = nodejs_22;
  npmDepsHash = "sha256-0hOGev0HglOQmofzPQMfiWh1opg6cpiEgsfK22AKcGk=";
  npmRebuildFlags = ["--ignore-scripts"];
  dontNpmBuild = true;

  nativeBuildInputs =
    [
      python3
      makeWrapper
    ]
    ++ lib.optionals stdenv.hostPlatform.isLinux [
      autoPatchelfHook
    ];

  buildInputs = lib.optionals stdenv.hostPlatform.isLinux [
    libuv
    stdenv.cc.cc.lib
  ];

  # node-pty is not hoisted to the root node_modules (package-lock.json pins it
  # under packages/server), but upstream's trace script globs the root path, so
  # the prebuilt pty.node never lands in $out and the terminal worker dies with
  # "Failed to load native module: pty.node".
  postPatch = ''
    substituteInPlace scripts/trace-daemon.mjs \
      --replace-fail "node_modules/node-pty/prebuilds/" "packages/server/node_modules/node-pty/prebuilds/"
  '';

  buildPhase = ''
    runHook preBuild

    npm rebuild node-pty
    npm run build:server
    npm run build:daemon-web-ui

    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall

    mkdir -p "$out/lib/paseo"
    node scripts/trace-daemon.mjs > daemon-files.txt

    while IFS= read -r path; do
      [ -z "$path" ] && continue
      mkdir -p "$out/lib/paseo/$(dirname "$path")"
      cp -a "$path" "$out/lib/paseo/$path"
    done < daemon-files.txt

    cp package.json "$out/lib/paseo/"
    cp -r packages/server/dist/server/web-ui "$out/lib/paseo/packages/server/dist/server/"

    mkdir -p "$out/bin"
    makeWrapper ${nodejs_22}/bin/node "$out/bin/paseo-server" \
      --add-flags "$out/lib/paseo/packages/server/dist/scripts/supervisor-entrypoint.js" \
      --set PASEO_NODE_ENV production
    makeWrapper ${nodejs_22}/bin/node "$out/bin/paseo" \
      --add-flags "$out/lib/paseo/packages/cli/dist/index.js" \
      --set NODE_PATH "$out/lib/paseo/node_modules"

    runHook postInstall
  '';

  meta = {
    description = "Self-hosted daemon for AI coding agents";
    homepage = "https://github.com/getpaseo/paseo";
    license = lib.licenses.agpl3Plus;
    mainProgram = "paseo";
    platforms = lib.platforms.linux ++ lib.platforms.darwin;
  };
}
