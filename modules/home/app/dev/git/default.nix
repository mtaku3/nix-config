{
  lib,
  config,
  pkgs,
  ...
}:
with lib;
with lib.capybara; let
  cfg = config.capybara.app.dev.git;
in {
  options.capybara.app.dev.git = {
    enable = mkBoolOpt false "Whether to enable the git";
    username = mkOpt types.str null "Name to configure git with";
    email = mkOpt types.str null "Email to configure git with";
    signingKey = mkOpt types.str "" "GPG key to sign commits with";
    signByDefault = mkBoolOpt true "Whether to sign commits by default";
  };

  imports = [./git-town.nix];

  config = mkIf cfg.enable {
    capybara.app.dev.zsh.oh-my-zsh.plugins = ["git"];

    programs.git = {
      enable = true;
      userName = cfg.username;
      userEmail = cfg.email;
      signing = {
        key = cfg.signingKey;
        inherit (cfg) signByDefault;
      };
      lfs = enabled;
      extraConfig = {
        init = {defaultBranch = "main";};
        pull = {rebase = true;};
        push = {autoSetupRemote = true;};
      };
      hooks = let
        pre-push-script = pkgs.writeShellScript "pre-push-script" ''
          # NOTE: https://gist.github.com/mosra/19abea23cdf6b82ce891c9410612e7e1
          # Add more branches separated by | if needed
          protected_branches='master|main'

          # Argument parsing taken from .git/hooks/pre-push.sample
          if read local_ref local_sha remote_ref remote_sha; then
            if [[ "$remote_ref" =~ ($protected_branches) ]]; then
                echo -en "\033[1;33mYou're about to push to $remote_ref, is that what you intended? [y|n] \033[0m"
                echo -en "\033[1m"
                read -n 1 -r < /dev/tty
                echo -en "\033[0m"

                echo
                if echo $REPLY | grep -E '^[Yy]$' > /dev/null; then
                    exit 0 # push will execute
                fi
                exit 1 # push will not execute
            fi
          fi
        '';
        post-checkout-script = pkgs.writeShellScript "post-checkout-script" ''
          GIT_DIR="$(git rev-parse --git-dir)"
          case "$GIT_DIR" in
            */.git/worktrees/*) : ;;
            *) exit 0 ;;
          esac

          CUR_WT="$(git rev-parse --show-toplevel)"
          COMMON_DIR="$(git rev-parse --git-common-dir)"
          TOP_WT="$(dirname "$COMMON_DIR")"

          FILES=( "devbox.json" "devbox.lock" ".envrc" ".nvim.lua" )

          for f in "${FILES[@]}"; do
            src="$TOP_WT/$f"
            dst="$CUR_WT/$f"
            if [ ! -e "$dst" ] && [ -e "$src" ]; then
              cp "$src" "$dst"
            fi
          done
        '';
      in {
        pre-push = pre-push-script;
        post-checkout = post-checkout-script;
      };
    };
  };
}
