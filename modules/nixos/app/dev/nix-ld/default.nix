{
  lib,
  config,
  pkgs,
  ...
}:
with lib;
with lib.capybara; let
  cfg = config.capybara.app.dev.nix-ld;
in {
  options.capybara.app.dev.nix-ld = with types; {
    enable = mkBoolOpt false "Whether to enable the nix-ld";
  };

  config = mkIf cfg.enable {
    programs.nix-ld = {
      enable = true;
      libraries = with pkgs; [
        zlib
        zstd
        stdenv.cc.cc
      ];
    };
  };
}
