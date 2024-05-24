{
  lib,
  config,
  ...
}:
with lib;
with lib.capybara; let
  cfg = config.capybara.app.dev.tmux;
in {
  options.capybara.app.dev.tmux = {
    enable = mkBoolOpt false "Whether to enable the tmux";
  };

  config = mkIf cfg.enable {
    programs.tmux = {
      enable = true;
      baseIndex = 1;
      keyMode = "vi";
      extraConfig = ''
        unbind C-b
        set-option -g prefix C-a
        bind-key C-a send-prefix

        set -g base-index 1

        bind -r ^ last-window
        bind -r h select-pane -L
        bind -r j select-pane -D
        bind -r k select-pane -U
        bind -r l select-pane -R
      '';
    };
  };
}
