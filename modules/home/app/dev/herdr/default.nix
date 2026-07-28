{
  lib,
  config,
  inputs,
  pkgs,
  ...
}:
with lib;
with lib.capybara; let
  cfg = config.capybara.app.dev.herdr;
in {
  options.capybara.app.dev.herdr = {
    enable = mkBoolOpt false "Whether to enable herdr, a terminal workspace manager for AI coding agents";

    package = mkOpt types.package inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.herdr ''
      The herdr package to install. Defaults to the build from the
      llm-agents.nix flake input, since herdr is not packaged in nixpkgs.
    '';
  };

  config = mkIf cfg.enable {
    home.packages = [cfg.package];

    # ~/.config/herdr holds more than config.toml: herdr writes its session
    # snapshot (session.json, and session-history.json when pane history is
    # enabled) alongside it, so the directory is state that has to survive
    # reboots on impermanent hosts. config.toml is deliberately left
    # unmanaged — herdr rewrites it itself (e.g. onboarding = false).
    capybara.impermanence.directories = [
      ".config/herdr"
    ];
  };
}
