{
  lib,
  pkgs,
  ...
}:
pkgs.buildGo126Module rec {
  pname = "gogcli";
  version = "0.43.0";

  src = pkgs.fetchFromGitHub {
    owner = "openclaw";
    repo = "gogcli";
    rev = "v${version}";
    hash = "sha256-b+AV56EmZJ9+PIapkBT6qqFtyaGMwQrftNSGYpXjwKE=";
  };

  vendorHash = "sha256-EBZhRTOgImlFWoTx0mYLtBLGC/GPBUoXGcpAswqxVdw=";

  subPackages = ["cmd/gog"];

  ldflags = [
    "-s"
    "-w"
    "-X github.com/openclaw/gogcli/internal/cmd.version=v${version}"
  ];

  meta = {
    description = "Script-friendly CLI for Gmail, Calendar, Drive and other Google APIs";
    homepage = "https://github.com/openclaw/gogcli";
    license = lib.licenses.mit;
    mainProgram = "gog";
    platforms = lib.platforms.linux ++ lib.platforms.darwin;
  };
}
