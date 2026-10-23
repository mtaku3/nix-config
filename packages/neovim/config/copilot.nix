{
  lib,
  pkgs,
  config,
  ...
}: {
  config = {
    plugins = {
      copilot-lua = {
        enable = true;

        # nixos-26.05 pins v2.0.4 with a hash that GitHub's archive of the tag
        # no longer matches (same commit b148240; the tree is unchanged).
        # Drop once nixpkgs updates the hash or the plugin.
        package = pkgs.vimPlugins.copilot-lua.overrideAttrs {
          src = pkgs.fetchFromGitHub {
            owner = "zbirenbaum";
            repo = "copilot.lua";
            tag = "v2.0.4";
            hash = "sha256-05f76OeWBlFmlUh90tH4XMMKfNI1jnhuIJDqYPPQokA=";
          };
        };

        settings = {
          suggestion.enabled = false;
          panel.enabled = false;

          filetypes = {
            markdown = true;
            help = true;
          };
        };
      };

      blink-copilot.enable = true;

      blink-cmp.settings.sources.providers.copilot = {
        name = "copilot";
        module = "blink-copilot";
        score_offset = 100;
        async = true;
      };
    };
  };
}
