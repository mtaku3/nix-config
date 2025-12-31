{
  lib,
  pkgs,
  config,
  ...
}: {
  config = {
    plugins.copilot-vim.enable = true;
  };
}
