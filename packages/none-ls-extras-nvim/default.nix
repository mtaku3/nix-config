{
  lib,
  pkgs,
  ...
}:
with lib;
with lib.capybara;
  pkgs.vimUtils.buildVimPlugin {
    name = "none-ls-extras-nvim";
    pname = "none-ls-extras-nvim";
    src = pkgs.fetchFromGitHub {
      owner = "nvimtools";
      repo = "none-ls-extras.nvim";
      rev = "924fe88a9983c7d90dbb31fc4e3129a583ea0a90";
      hash = "sha256-OJHg2+h3zvlK7LJ8kY6f7et0w6emnxfcDbjD1YyWRTw=";
    };
    dependencies = [pkgs.vimPlugins.none-ls-nvim];
  }
