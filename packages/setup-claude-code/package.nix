{
  lib,
  python3,
  formats,
  runCommand,
  makeWrapper,
  defaultGroups,
  postInstall,
  plugins,
  permissions,
  sandbox,
  mcp,
}: let
  configFile =
    (formats.json {}).generate "setup-claude-code.json"
    {inherit defaultGroups postInstall plugins permissions sandbox mcp;};
in
  runCommand "setup-claude-code" {
    pname = "setup-claude-code";
    nativeBuildInputs = [makeWrapper];
    meta.platforms = lib.platforms.unix;
  } ''
    mkdir -p $out/bin
    makeWrapper ${python3}/bin/python3 $out/bin/setup-claude-code \
      --add-flags "${./setup-claude-code.py} --config ${configFile}"
  ''
