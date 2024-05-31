{
  lib,
  pkgs,
  ...
}:
with lib;
with lib.capybara;
  pkgs.neovim-unwrapped.override {
    treesitter-parsers = {};
  }
