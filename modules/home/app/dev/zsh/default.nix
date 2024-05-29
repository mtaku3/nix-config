{
  lib,
  config,
  pkgs,
  ...
}:
with lib;
with lib.capybara; let
  cfg = config.capybara.app.dev.zsh;
in {
  options.capybara.app.dev.zsh = {
    enable = mkBoolOpt false "Whether to enable the zsh";
    package = mkPackageOption pkgs "zsh" {};

    oh-my-zsh = mkOpt (types.submodule {
      options = {
        plugins = mkOption {
          default = [ "git" "sudo" ];
          example = [ "git" "sudo" ];
          type = types.listOf types.str;
          description = ''
            List of oh-my-zsh plugins
          '';
        };
      };
    }) {} "Options to configure oh-my-zsh";
  };

  config = mkIf cfg.enable {
    programs.zsh = {
      enable = true;
      oh-my-zsh = {
        enable = true;
        plugins = cfg.oh-my-zsh.plugins;
        theme = "robbyrussell";
      };
      package = cfg.package;
    };
  };
}
