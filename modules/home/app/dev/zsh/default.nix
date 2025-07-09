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
          default = ["git" "sudo"];
          example = ["git" "sudo"];
          type = types.listOf types.str;
          description = ''
            List of oh-my-zsh plugins
          '';
        };
      };
    }) {} "Options to configure oh-my-zsh";
  };

  config = mkIf cfg.enable {
    capybara.app.dev.zsh.oh-my-zsh.plugins = ["sudo"];
    capybara.shell.path = "${cfg.package}/bin/zsh";

    programs.zsh = {
      enable = true;
      plugins = [
        {
          name = "zsh-powerlevel10k";
          src = "${pkgs.zsh-powerlevel10k}/share/zsh-powerlevel10k/";
          file = "powerlevel10k.zsh-theme";
        }
        {
          name = "powerlevel10k-config";
          src = ./powerlevel10k-config;
          file = "config.zsh";
        }
      ];
      oh-my-zsh = {
        enable = true;
        plugins = cfg.oh-my-zsh.plugins;
      };
      package = cfg.package;
    };
  };
}
