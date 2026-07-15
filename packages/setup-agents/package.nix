{
  python3,
  formats,
  runCommand,
  makeWrapper,
  defaultGroups,
  postInstall,
  plugins,
  permissions,
  mcp,
}: let
  configFile =
    (formats.json {}).generate "setup-agents.json"
    {inherit defaultGroups postInstall plugins permissions mcp;};
in
  runCommand "setup-agents" {
    pname = "setup-agents";
    nativeBuildInputs = [makeWrapper];
  } ''
    mkdir -p $out/bin
    makeWrapper ${python3}/bin/python3 $out/bin/setup-agents \
      --add-flags "${./setup-agents.py} --config ${configFile}"
  ''
