{
  lib,
  config,
  pkgs,
  ...
}:
with lib;
with lib.capybara; let
  cfg = config.capybara.app.dev.claude-code;
  claude-code = pkgs.symlinkJoin {
    name = "claude-code";
    paths = [pkgs.unstable.claude-code];
    buildInputs = [pkgs.makeWrapper];
    postBuild = ''
      wrapProgram $out/bin/claude \
        --prefix PATH : ${pkgs.uv}/bin \
        --prefix PATH : ${pkgs.python312}/bin \
        --prefix PATH : ${pkgs.nodejs_24}/bin
    '';
  };
in {
  options.capybara.app.dev.claude-code = {
    enable = mkBoolOpt false "Whether to enable the claude-code";
  };

  config = mkIf cfg.enable {
    home.packages = [
      claude-code
      pkgs.unstable.repomix
      pkgs.capybara.superclaude
    ];

    capybara.impermanence.directories = [".claude"];
    capybara.impermanence.files = [".claude.json"];
  };
}
