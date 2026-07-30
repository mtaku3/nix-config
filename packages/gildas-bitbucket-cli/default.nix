{
  lib,
  pkgs,
  ...
}:
pkgs.buildGo126Module rec {
  pname = "gildas-bitbucket-cli";
  version = "0.18.4";

  src = pkgs.fetchFromGitHub {
    owner = "gildas";
    repo = "bitbucket-cli";
    rev = "v${version}";
    hash = "sha256-kGDNnfSDNdFZkVDEu7BsMAe1nXwzgFndibtq6jl6QaA=";
  };

  vendorHash = "sha256-p4jlcxvOslGOXk58X3dJ6/WiFOEjCACnx5pwsvH0o28=";

  postInstall = ''
    mv "$out/bin/bitbucket-cli" "$out/bin/bb"
  '';

  meta = {
    description = "Command-line interface for Bitbucket";
    homepage = "https://github.com/gildas/bitbucket-cli";
    license = lib.licenses.mit;
    mainProgram = "bb";
    platforms = lib.platforms.linux ++ lib.platforms.darwin;
  };
}
