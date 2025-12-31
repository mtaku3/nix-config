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
