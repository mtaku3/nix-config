{
  lib,
  pkgs,
  config,
  ...
}: {
  config = {
    plugins.conform-nvim = {
      enable = true;

      settings = {
        formatters_by_ft = {
          nix = ["alejandra"];
        };

        formatters = {
          nixfmt.command = lib.getExe pkgs.alejandra;
        };
      };
    };

    keymaps = [
      {
        key = "<leader>f";
        action = lib.nixvim.mkRaw "function() require('conform').format() end";
        options.desc = "LSP: Format";
      }
    ];
  };
}
